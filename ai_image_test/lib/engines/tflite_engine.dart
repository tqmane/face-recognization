import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/benchmark_run.dart';
import 'engine.dart';

/// TFLite engine – GPU on mobile/macOS via delegates; CPU everywhere.
class TfliteEngine implements InferenceEngine {
  final String modelName;
  final String modelPath;
  final int inputSize;
  final String device; // CPU | GPU
  final int threads;

  Interpreter? _interp;
  String _actualDevice = 'CPU';

  TfliteEngine({
    required this.modelName,
    required this.modelPath,
    this.inputSize = 224,
    this.device = 'CPU',
    this.threads = 4,
  });

  @override
  String get name => '$modelName (TFLite-$_actualDevice)';

  String get actualDevice => _actualDevice;

  static List<String> get availableDevices {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return ['CPU', 'GPU'];
    }
    return ['CPU'];
  }

  @override
  Future<void> initialize() async {
    final opts = InterpreterOptions()..threads = threads;
    Delegate? gpuDelegate;

    if (device == 'GPU') {
      try {
        if (Platform.isAndroid) {
          gpuDelegate = GpuDelegateV2(
            options: GpuDelegateOptionsV2(isPrecisionLossAllowed: true),
          );
        } else if (Platform.isIOS || Platform.isMacOS) {
          gpuDelegate = GpuDelegate();
        }
        if (gpuDelegate != null) opts.addDelegate(gpuDelegate);
      } catch (e) {
        debugPrint('TfliteEngine: GPU delegate failed, falling back to CPU: $e');
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
      _interp = Interpreter.fromBuffer(bytes, options: opts);
      _actualDevice = gpuDelegate != null ? 'GPU' : 'CPU';
    } catch (e) {
      // GPU may fail at allocation time; retry without delegate.
      if (gpuDelegate != null) {
        debugPrint('TfliteEngine: GPU interpreter failed, retrying CPU: $e');
        gpuDelegate.delete();
        final cpuOpts = InterpreterOptions()..threads = threads;
        _interp = Interpreter.fromBuffer(bytes, options: cpuOpts);
        _actualDevice = 'CPU';
      } else {
        rethrow;
      }
    }

    debugPrint('TfliteEngine ready: $name');
  }

  @override
  void dispose() {
    _interp?.close();
    _interp = null;
  }

  @override
  Future<double> compareImages(String p1, String p2) async {
    final e1 = await _embed(p1);
    final e2 = await _embed(p2);
    if (e1 == null || e2 == null) return 0;
    return _cosine(e1, e2);
  }

  Future<List<double>?> _embed(String path) async {
    if (_interp == null) return null;
    final raw = await _preprocess(path);
    if (raw == null) return null;
    return _runInference(raw);
  }

  Future<List<double>?> _preprocess(String path) async {
    try {
      final image = img.decodeImage(await File(path).readAsBytes());
      if (image == null) return null;
      final resized = img.copyResize(image, width: inputSize, height: inputSize);
      final data = <double>[];
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final px = resized.getPixel(x, y);
          data.addAll([px.r / 255.0, px.g / 255.0, px.b / 255.0]);
        }
      }
      return data;
    } catch (e) {
      debugPrint('TfliteEngine: preprocess error: $e');
      return null;
    }
  }

  List<double>? _runInference(List<double> input) {
    if (_interp == null) return null;
    final inShape = _interp!.getInputTensor(0).shape; // e.g. [1,224,224,3]
    final inData = input.reshape(inShape);

    final outTensor = _interp!.getOutputTensor(0);
    final outShape = outTensor.shape;
    int outSize = 1;
    for (final s in outShape) outSize *= s;

    final output = outTensor.type == TensorType.float32
        ? List<double>.filled(outSize, 0).reshape(outShape)
        : List<int>.filled(outSize, 0).reshape(outShape);

    _interp!.run(inData, output);
    return _flatten(output);
  }

  List<double> _flatten(dynamic d) {
    if (d is double) return [d];
    if (d is int) return [d.toDouble()];
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
    for (int i = 0; i < warmupRuns; i++) _runInference(dummy);

    final times = <double>[];
    for (int i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      _runInference(dummy);
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
