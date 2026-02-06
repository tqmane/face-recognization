import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../models/benchmark_run.dart';
import 'engine.dart';

/// ONNX Runtime engine – CoreML on Apple, NNAPI/XNNPACK on Android, CPU on desktop.
class OnnxEngine implements InferenceEngine {
  final String modelName;
  final String modelPath;
  final int inputSize;
  final String device;
  final int threads;

  OrtSession? _session;
  OrtSessionOptions? _opts;
  List<String>? _inputNames;

  OnnxEngine({
    required this.modelName,
    required this.modelPath,
    this.inputSize = 224,
    this.device = 'CPU',
    this.threads = 4,
  });

  @override
  String get name => '$modelName (ONNX-$device)';

  static List<String> get availableDevices {
    if (Platform.isMacOS || Platform.isIOS) return ['CPU', 'CoreML'];
    if (Platform.isAndroid) return ['CPU', 'NNAPI', 'XNNPACK'];
    return ['CPU', 'XNNPACK'];
  }

  @override
  Future<void> initialize() async {
    OrtEnv.instance.init();
    _opts = OrtSessionOptions()..setIntraOpNumThreads(threads);

    if (device == 'CoreML' && (Platform.isMacOS || Platform.isIOS)) {
      _opts!.appendCoreMLProvider(CoreMLFlags.useNone);
    } else if (device == 'NNAPI' && Platform.isAndroid) {
      _opts!.appendNnapiProvider(NnapiFlags.useNone);
    } else if (device == 'XNNPACK') {
      _opts!.appendXnnpackProvider();
    } else {
      _opts!.appendCPUProvider(CPUFlags.useNone);
    }

    Uint8List bytes;
    final f = File(modelPath);
    if (f.isAbsolute && await f.exists()) {
      bytes = await f.readAsBytes();
    } else {
      bytes = Uint8List.view((await rootBundle.load(modelPath)).buffer);
    }

    _session = OrtSession.fromBuffer(bytes, _opts!);
    _inputNames = _session!.inputNames;
    debugPrint('OnnxEngine ready: $name (inputs=$_inputNames)');
  }

  @override
  void dispose() {
    _session?.release();
    _opts?.release();
    OrtEnv.instance.release();
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
      // NCHW format
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final px = resized.getPixel(x, y);
            data.add((c == 0 ? px.r : c == 1 ? px.g : px.b) / 255.0);
          }
        }
      }
      return data;
    } catch (e) {
      debugPrint('OnnxEngine: preprocess error: $e');
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
      return _flatten(raw);
    } finally {
      tensor.release();
    }
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
    return dot / (sqrt(na) * sqrt(nb));
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
