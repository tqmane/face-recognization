import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../models/benchmark_run.dart';
import 'engine.dart';
import '../services/onnx_directml_ffi.dart';

/// ONNX Runtime engine with DirectML support for Windows GPU acceleration.
/// 
/// This engine extends the standard ONNX Runtime to support DirectML on Windows,
/// which enables GPU acceleration on NVIDIA, AMD, and Intel GPUs.
/// On other platforms, it falls back to standard ONNX Runtime behavior.
class OnnxDirectMLEngine implements InferenceEngine {
  final String modelName;
  final String modelPath;
  final int inputSize;
  final String device;
  final int threads;

  OrtSession? _session;
  OrtSessionOptions? _opts;
  List<String>? _inputNames;
  String _actualDevice = 'CPU';
  OnnxRuntimeDirectML? _directML;

  OnnxDirectMLEngine({
    required this.modelName,
    required this.modelPath,
    this.inputSize = 224,
    this.device = 'DirectML',
    this.threads = 4,
  });

  @override
  String get name => '$modelName (ONNX-$_actualDevice)';

  String get actualDevice => _actualDevice;

  static List<String> get availableDevices {
    final devices = ['CPU', 'XNNPACK'];
    
    if (Platform.isWindows) {
      // Check if DirectML is available
      if (OnnxRuntimeDirectML.isAvailable()) {
        devices.add('DirectML');
      }
    }
    
    return devices;
  }

  @override
  Future<void> initialize() async {
    OrtEnv.instance.init();
    _opts = OrtSessionOptions()..setIntraOpNumThreads(threads);

    bool gpuInitialized = false;

    // Try to initialize DirectML on Windows.
    //
    // NOTE: The high-level `onnxruntime` Dart package (v1.4.x) does NOT
    // expose an `appendExecutionProvider_DML` method on OrtSessionOptions.
    // True DirectML GPU acceleration therefore requires:
    //   1. `onnxruntime-directml.dll` (from Microsoft.ML.OnnxRuntime.DirectML)
    //      placed next to the app executable, AND
    //   2. Calling OrtSessionOptions_AppendExecutionProvider_DML via the raw
    //      C API (see OnnxRuntimeDirectML in onnx_directml_ffi.dart).
    //
    // Because the Dart package manages the OrtSessionOptions* pointer
    // internally and does not expose it, we cannot inject the DirectML
    // provider into the high-level session options object at this time.
    // Instead, XNNPACK is used as the best CPU-accelerated fallback.
    // Replace the lines below with a proper DirectML injection once the
    // package exposes the raw options pointer or a dedicated pub package
    // (e.g. `onnxruntime_directml`) becomes available.
    if (device == 'DirectML' && Platform.isWindows) {
      try {
        _directML = OnnxRuntimeDirectML();
        if (_directML!.initialize()) {
          if (_directML!.isDirectMLFunctionAvailable) {
            // DirectML DLL is present and the provider function is resolved.
            // Ideally we would call:
            //   _directML!.appendExecutionProviderDML(optionsPtr, 0)
            // but the OrtSessionOptions* pointer is not accessible from
            // the Dart package's public API.
            // Falling back to XNNPACK as the next-best option.
            debugPrint('OnnxDirectMLEngine: DirectML DLL found but cannot inject '
                'provider via Dart package API; using XNNPACK');
          } else {
            debugPrint('OnnxDirectMLEngine: onnxruntime-directml.dll not found; '
                'using XNNPACK (install DirectML DLL for GPU acceleration)');
          }
          _opts!.appendXnnpackProvider();
          _actualDevice = 'XNNPACK';
          gpuInitialized = true;
        }
      } catch (e) {
        debugPrint('OnnxDirectMLEngine: DirectML initialization failed: $e');
      }
    }

    // If DirectML not initialized, use requested device
    if (!gpuInitialized) {
      if (device == 'XNNPACK') {
        _opts!.appendXnnpackProvider();
        _actualDevice = 'XNNPACK';
      } else {
        _opts!.appendCPUProvider(CPUFlags.useNone);
        _actualDevice = 'CPU';
      }
    }

    Uint8List bytes;
    final f = File(modelPath);
    if (f.isAbsolute && await f.exists()) {
      bytes = await f.readAsBytes();
    } else {
      bytes = Uint8List.view((await rootBundle.load(modelPath)).buffer);
    }

    try {
      _session = OrtSession.fromBuffer(bytes, _opts!);
      _inputNames = _session!.inputNames;
      debugPrint('OnnxDirectMLEngine ready: $name (inputs=$_inputNames)');
    } catch (e) {
      debugPrint('Failed to create ONNX session: $e');
      // Retry with CPU as fallback
      if (_actualDevice != 'CPU') {
        debugPrint('Retrying with CPU...');
        _opts?.release();
        _opts = OrtSessionOptions()..setIntraOpNumThreads(threads);
        _opts!.appendCPUProvider(CPUFlags.useNone);
        _session = OrtSession.fromBuffer(bytes, _opts!);
        _inputNames = _session!.inputNames;
        _actualDevice = 'CPU';
        debugPrint('OnnxDirectMLEngine ready (CPU fallback): $name');
      } else {
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _session?.release();
    _opts?.release();
    _directML?.dispose();
    // Note: Don't call OrtEnv.instance.release() here as it's a singleton
    // and may be used by other engines
  }

  @override
  Future<double> compareImages(String p1, String p2) async {
    final e1 = await _embed(p1);
    final e2 = await _embed(p2);
    if (e1 == null || e2 == null) return 0;
    return _cosine(e1, e2);
  }

  Future<List<double>?> _embed(String path) async {
    final input = await _preprocess(path);
    if (input == null) return null;
    return _runInference(input);
  }

  Future<List<double>?> _preprocess(String path) async {
    try {
      final image = img.decodeImage(await File(path).readAsBytes());
      if (image == null) return null;
      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      final data = <double>[];
      // NCHW format: (pixel - 127.5) / 127.5 正規化 → [-1.0, 1.0]
      // MobileFaceNet等の顔認証モデルの標準的な前処理
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final px = resized.getPixel(x, y);
            final raw = c == 0 ? px.r : c == 1 ? px.g : px.b;
            data.add((raw - 127.5) / 127.5);
          }
        }
      }
      return data;
    } catch (e) {
      debugPrint('OnnxDirectMLEngine: preprocess error: $e');
      return null;
    }
  }

  Future<List<double>?> _runInference(List<double> input) async {
    if (_session == null) return null;
    final shape = [1, 3, inputSize, inputSize];
    final tensor = OrtValueTensor.createTensorWithDataList(input, shape);
    try {
      final runOpts = OrtRunOptions();
      final outputs = await _session!.runAsync(runOpts, {_inputNames!.first: tensor});
      runOpts.release();
      if (outputs == null || outputs.isEmpty) return null;
      final raw = outputs.first?.value;
      for (final o in outputs) o?.release();
      if (raw == null) return null;
      return _normalizeEmbedding(_flatten(raw));
    } finally {
      tensor.release();
    }
  }

  /// L2正規化で埋め込みベクトルを正規化
  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0;
    for (final v in embedding) norm += v * v;
    norm = sqrt(norm);
    if (norm == 0) return embedding;
    return embedding.map((v) => v / norm).toList();
  }

  List<double> _flatten(dynamic d) {
    if (d is double) return [d];
    if (d is int) return [d.toDouble()];
    if (d is num) return [d.toDouble()];
    if (d is List) return d.expand((e) => _flatten(e)).toList();
    return [];
  }

  double _cosine(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    final sim = dot / (sqrt(na) * sqrt(nb));
    return sim.clamp(0.0, 1.0);
  }

  @override
  Future<PerfStats> runSyntheticBenchmark({int warmupRuns = 30, int runs = 200}) async {
    final dummy = List<double>.filled(inputSize * inputSize * 3, 0.5);
    for (int i = 0; i < warmupRuns; i++) await _runInference(dummy);

    final times = <double>[];
    for (int i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      await _runInference(dummy);
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000.0);
    }
    times.sort();
    return PerfStats(
      runs: runs,
      meanMs: times.reduce((a, b) => a + b) / times.length,
      p50Ms: times[(times.length * 0.5).floor()],
      p90Ms: times[(times.length * 0.9).floor()],
      minMs: times.first,
      maxMs: times.last,
    );
  }
}
