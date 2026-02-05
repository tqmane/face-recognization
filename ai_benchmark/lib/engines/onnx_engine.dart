import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'inference_engine.dart';
import '../services/performance_benchmark.dart';

/// ONNX Runtime engine with GPU support on Windows/Linux via DirectML/CUDA
class OnnxEngine implements InferenceEngine {
  final String _modelName;
  final String _modelPath;
  final int _inputSize;
  final String device;
  final int threads;

  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  List<String>? _inputNames;
  List<String>? _outputNames;

  OnnxEngine({
    required String modelName,
    required String modelPath,
    int inputSize = 224,
    this.device = 'CPU',
    this.threads = 4,
  })  : _modelName = modelName,
        _modelPath = modelPath,
        _inputSize = inputSize;

  @override
  String get name => '$_modelName (ONNX-$device)';

  /// Check if GPU acceleration is available via ONNX Runtime
  /// Note: The Flutter onnxruntime package only supports CoreML (Apple) and NNAPI (Android)
  /// DirectML and CUDA are not available in the Flutter binding
  static bool get isGpuAvailable {
    return Platform.isMacOS || Platform.isIOS || Platform.isAndroid;
  }

  /// Get available device options for ONNX Runtime
  /// Note: DirectML/CUDA not available in Flutter onnxruntime package
  static List<String> get availableDevices {
    if (Platform.isMacOS || Platform.isIOS) {
      return ['CPU', 'CoreML'];
    } else if (Platform.isAndroid) {
      return ['CPU', 'NNAPI', 'XNNPACK'];
    }
    // Windows/Linux: CPU only with XNNPACK optimization
    return ['CPU', 'XNNPACK'];
  }

  @override
  Future<void> initialize() async {
    try {
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      _sessionOptions = OrtSessionOptions();

      // Configure execution providers based on device
      // Note: Flutter onnxruntime only supports CoreML, NNAPI, XNNPACK, and CPU
      if (device == 'CoreML' && (Platform.isMacOS || Platform.isIOS)) {
        // CoreML for Apple devices
        _sessionOptions!.appendCoreMLProvider(CoreMLFlags.useNone);
        debugPrint('Using CoreML provider');
      } else if (device == 'NNAPI' && Platform.isAndroid) {
        // NNAPI for Android
        _sessionOptions!.appendNnapiProvider(NnapiFlags.useNone);
        debugPrint('Using NNAPI provider');
      } else if (device == 'XNNPACK') {
        // XNNPACK for optimized CPU execution
        _sessionOptions!.appendXnnpackProvider();
        debugPrint('Using XNNPACK provider');
      } else {
        // Default CPU provider
        _sessionOptions!.appendCPUProvider(CPUFlags.useNone);
        debugPrint('Using CPU provider with $threads threads');
      }

      // Set thread count for CPU execution
      _sessionOptions!.setIntraOpNumThreads(threads);

      // Load model
      Uint8List modelBytes;
      if (File(_modelPath).isAbsolute && await File(_modelPath).exists()) {
        modelBytes = await File(_modelPath).readAsBytes();
      } else {
        final rawAsset = await rootBundle.load(_modelPath);
        modelBytes = rawAsset.buffer.asUint8List();
      }

      _session = OrtSession.fromBuffer(modelBytes, _sessionOptions!);

      // Get input/output names
      _inputNames = _session!.inputNames;
      _outputNames = _session!.outputNames;

      debugPrint('Loaded ONNX model: $_modelName');
      debugPrint('  Inputs: $_inputNames');
      debugPrint('  Outputs: $_outputNames');

      // Warmup
      await _warmup();
    } catch (e) {
      debugPrint('Failed to initialize ONNX model on $device: $e');
      throw Exception('Failed to initialize ONNX model: $e');
    }
  }

  Future<void> _warmup() async {
    // Create dummy input for warmup
    final shape = [1, 3, _inputSize, _inputSize]; // NCHW format typical for ONNX
    final data = List.filled(_inputSize * _inputSize * 3, 0.0);
    final inputTensor = OrtValueTensor.createTensorWithDataList(data, shape);

    try {
      final inputs = {_inputNames!.first: inputTensor};
      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(runOptions, inputs);

      runOptions.release();
      if (outputs != null) {
        for (final e in outputs) {
          e?.release();
        }
      }
    } finally {
      inputTensor.release();
    }
  }

  @override
  void dispose() {
    _session?.release();
    _sessionOptions?.release();
    OrtEnv.instance.release();
  }

  @override
  Future<double> compareImages(String imagePath1, String imagePath2) async {
    if (_session == null) return 0.0;

    final input1 = await _preprocessImage(imagePath1);
    final input2 = await _preprocessImage(imagePath2);

    if (input1 == null || input2 == null) return 0.0;

    final output1 = await _runInference(input1);
    final output2 = await _runInference(input2);

    if (output1 == null || output2 == null) return 0.0;

    return _cosineSimilarity(output1, output2);
  }

  Future<List<double>?> _preprocessImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

      // ONNX typically uses NCHW format with normalized values
      final data = <double>[];

      // Channel-first format (CHW)
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < _inputSize; y++) {
          for (int x = 0; x < _inputSize; x++) {
            final pixel = resized.getPixel(x, y);
            double value;
            switch (c) {
              case 0:
                value = pixel.r / 255.0;
                break;
              case 1:
                value = pixel.g / 255.0;
                break;
              case 2:
                value = pixel.b / 255.0;
                break;
              default:
                value = 0.0;
            }
            data.add(value);
          }
        }
      }

      return data;
    } catch (e) {
      debugPrint('Image preprocessing error: $e');
      return null;
    }
  }

  Future<List<double>?> _runInference(List<double> inputData) async {
    if (_session == null) return null;

    final shape = [1, 3, _inputSize, _inputSize];
    final inputTensor = OrtValueTensor.createTensorWithDataList(inputData, shape);

    try {
      final inputs = {_inputNames!.first: inputTensor};
      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(runOptions, inputs);

      if (outputs == null || outputs.isEmpty) {
        runOptions.release();
        return null;
      }

      // Get output tensor data
      final outputTensor = outputs.first;
      final outputData = outputTensor?.value as List<dynamic>?;

      runOptions.release();
      for (final e in outputs) {
        e?.release();
      }

      if (outputData == null) return null;

      // Flatten output to 1D list of doubles
      return _flatten(outputData).map((e) => e.toDouble()).toList();
    } finally {
      inputTensor.release();
    }
  }

  List<num> _flatten(dynamic data) {
    if (data is num) return [data];
    if (data is List) {
      return data.expand((e) => _flatten(e)).toList();
    }
    return [];
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Run synthetic benchmark (similar to TfliteEngine)
  @override
  Future<BenchmarkStats> runSyntheticBenchmark({
    int warmupRuns = 30,
    int runs = 200,
  }) async {
    final inputData = List.filled(_inputSize * _inputSize * 3, 0.5);

    // Warmup
    for (int i = 0; i < warmupRuns; i++) {
      await _runInference(inputData);
    }

    // Benchmark
    final times = <double>[];
    for (int i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      await _runInference(inputData);
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000.0);
    }

    times.sort();
    final mean = times.reduce((a, b) => a + b) / times.length;
    final p50 = times[(times.length * 0.5).floor()];
    final p90 = times[(times.length * 0.9).floor()];

    return BenchmarkStats(
      runs: runs,
      meanMs: mean,
      p50Ms: p50,
      p90Ms: p90,
      minMs: times.first,
      maxMs: times.last,
    );
  }
}
