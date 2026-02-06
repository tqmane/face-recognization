import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'inference_engine.dart';
import '../services/performance_benchmark.dart';

class TfliteEngine implements InferenceEngine {
  final String _modelName;
  final String _modelPath;
  final int _inputSize;
  final String device;
  final int threads;
  Interpreter? _interpreter;
  Delegate? _delegate;

  /// The device actually used after initialization (may differ from [device]
  /// when GPU fallback to CPU occurs).
  String _actualDevice = '';

  TensorType? _inputTensorType;
  TensorType? _outputTensorType;
  List<int>? _inputShape;
  
  TfliteEngine({
    required String modelName, 
    required String modelPath,
    int inputSize = 224,
    this.device = 'CPU',
    this.threads = 4,
    bool useGpu = false
  }) : _modelName = modelName,
       _modelPath = modelPath,
       _inputSize = inputSize;

  @override
  String get name => '$_modelName ($_actualDevice)';

  /// The device that is actually being used (set after [initialize]).
  String get actualDevice => _actualDevice;

  /// Check if GPU acceleration is available on the current platform
  static bool get isGpuAvailable {
    // GPU delegates available on: Android (OpenCL/OpenGL), iOS/macOS (Metal)
    // Not available on: Windows, Linux (TFLite C API doesn't include GPU delegate)
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Get available device options for the current platform
  static List<String> get availableDevices {
    if (Platform.isAndroid) {
      return ['CPU', 'GPU'];
    } else if (Platform.isIOS || Platform.isMacOS) {
      return ['CPU', 'GPU'];
    } else {
      // Windows, Linux - only CPU available via TFLite C API
      return ['CPU'];
    }
  }

  @override
  Future<void> initialize() async {
    _actualDevice = device;

    try {
      final options = InterpreterOptions();
      options.threads = threads;

      Delegate? gpuDelegate;

      // Hardware Acceleration setup
      if (device == 'GPU') {
        gpuDelegate = _createGpuDelegate();
        if (gpuDelegate != null) {
          options.addDelegate(gpuDelegate);
        } else {
          // Delegate creation failed — will load as CPU.
          debugPrint('GPU delegate creation failed, falling back to CPU.');
          _actualDevice = 'CPU (GPU不可)';
        }
      }

      // Load interpreter — try with GPU delegate first, fallback to CPU on error.
      try {
        _interpreter = await _loadInterpreter(options);
      } catch (e) {
        if (gpuDelegate != null) {
          // GPU delegate caused the load failure → retry CPU-only.
          debugPrint('Interpreter creation with GPU failed ($e), retrying CPU-only.');
          gpuDelegate.delete();
          gpuDelegate = null;

          final cpuOptions = InterpreterOptions()..threads = threads;
          _interpreter = await _loadInterpreter(cpuOptions);
          _actualDevice = 'CPU (GPUフォールバック)';
        } else {
          rethrow;
        }
      }

      _delegate = gpuDelegate;

      debugPrint('Loaded TFLite model: $_modelName from $_modelPath on $_actualDevice');

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      _inputTensorType = inputTensor.type;
      _outputTensorType = outputTensor.type;
      _inputShape = inputTensor.shape;

      // Warn about quantised model + GPU (common source of crashes).
      if (device == 'GPU' && _inputTensorType != TensorType.float32) {
        debugPrint('⚠ 量子化モデル($_inputTensorType)でGPUを使用しています。'
            '一部デバイスではクラッシュする可能性があります。');
      }

      // Warmup — wrapped in try/catch so that a GPU crash during the first
      // inference does not kill the app without an error message.
      final warmupInput = _createZeroInput();
      if (warmupInput != null) {
        try {
          _runInference(warmupInput);
        } catch (e) {
          if (gpuDelegate != null) {
            debugPrint('Warmup inference with GPU failed ($e), reinitialising CPU-only.');
            _interpreter?.close();
            _delegate?.delete();
            _delegate = null;

            final cpuOptions = InterpreterOptions()..threads = threads;
            _interpreter = await _loadInterpreter(cpuOptions);
            _actualDevice = 'CPU (GPU推論エラー)';

            // Refresh tensor info
            final inT = _interpreter!.getInputTensor(0);
            final outT = _interpreter!.getOutputTensor(0);
            _inputTensorType = inT.type;
            _outputTensorType = outT.type;
            _inputShape = inT.shape;

            // Retry warmup on CPU
            final cpuWarmup = _createZeroInput();
            if (cpuWarmup != null) _runInference(cpuWarmup);
          } else {
            rethrow;
          }
        }
      }
      
    } catch (e) {
      debugPrint('Failed to load TFLite model on $device: $e');
      throw Exception('Failed to initialize model on $device: $e');
    }
  }

  /// Create a GPU delegate for the current platform, or null on failure.
  Delegate? _createGpuDelegate() {
    try {
      if (Platform.isAndroid) {
        // isPrecisionLossAllowed = true enables FP16, greatly improving
        // compatibility with quantised and some float32 models on mobile GPUs.
        final delegate = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: true,
          ),
        );
        debugPrint('Created Android GpuDelegateV2 (isPrecisionLossAllowed=true)');
        return delegate;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final delegate = GpuDelegate();
        debugPrint('Created Metal GpuDelegate');
        return delegate;
      }
    } catch (e) {
      debugPrint('GPU delegate creation error: $e');
    }
    return null;
  }

  /// Load interpreter from asset or file.
  Future<Interpreter> _loadInterpreter(InterpreterOptions options) async {
    if (File(_modelPath).isAbsolute) {
      return Interpreter.fromFile(File(_modelPath), options: options);
    } else {
      return await Interpreter.fromAsset(_modelPath, options: options);
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _delegate?.delete();
  }

  @override
  Future<double> compareImages(String imagePath1, String imagePath2) async {
    if (_interpreter == null) return 0.0;

    final input1 = await _preprocessImage(imagePath1);
    final input2 = await _preprocessImage(imagePath2);
    
    if (input1 == null || input2 == null) return 0.0;

    final output1 = _runInference(input1);
    final output2 = _runInference(input2);

    return _cosineSimilarity(output1, output2);
  }

  List<double>? _runInference(List<dynamic> input) {
    if (_interpreter == null) return null;

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;

    int outputSize = 1;
    for (final s in outputShape) {
      outputSize *= s;
    }

    dynamic output;
    final type = _outputTensorType ?? outputTensor.type;
    if (type == TensorType.float32) {
      output = List.filled(outputSize, 0.0).reshape(outputShape);
    } else {
      output = List.filled(outputSize, 0).reshape(outputShape);
    }

    _interpreter!.run(input, output);

    final rawVec = output[0] as List;
    return _decodeOutputVector(rawVec, outputTensor);
  }

  Future<List<dynamic>?> _preprocessImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
      
      final inputType = _inputTensorType;

      // Most vision models expect either uint8 [0..255] or float32 normalized.
      // For float32 we use MobileNet-style normalization: (x - 127.5) / 127.5.
      final input = List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          if (inputType == TensorType.float32) {
            final r = (pixel.r.toDouble() - 127.5) / 127.5;
            final g = (pixel.g.toDouble() - 127.5) / 127.5;
            final b = (pixel.b.toDouble() - 127.5) / 127.5;
            return <double>[r, g, b];
          }
          return <int>[pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        });
      });

      return [input];
    } catch (e) {
      debugPrint('Error preprocessing image: $e');
      return null;
    }
  }

  double _cosineSimilarity(List<double>? vec1, List<double>? vec2) {
    if (vec1 == null || vec2 == null) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    final len = vec1.length < vec2.length ? vec1.length : vec2.length;
    for (int i = 0; i < len; i++) {
      final v1 = vec1[i];
      final v2 = vec2[i];
      
      dotProduct += v1 * v2;
      normA += v1 * v1;
      normB += v2 * v2;
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  List<dynamic>? _createZeroInput() {
    if (_inputShape == null) return null;
    final shape = _inputShape!;
    int size = 1;
    for (final s in shape) {
      size *= s;
    }

    if (_inputTensorType == TensorType.float32) {
      return List.filled(size, 0.0).reshape(shape);
    }
    return List.filled(size, 0).reshape(shape);
  }

  List<double> _decodeOutputVector(List rawVec, Tensor outputTensor) {
    final type = _outputTensorType ?? outputTensor.type;
    if (type == TensorType.float32) {
      return rawVec.map((e) => (e as num).toDouble()).toList(growable: false);
    }

    // Quantized output: dequantize if params are available, otherwise cast.
    try {
      final qp = outputTensor.params;
      final scale = qp.scale;
      final zeroPoint = qp.zeroPoint;

      if (scale != 0.0) {
        return rawVec
            .map((e) => (((e as num).toInt() - zeroPoint) * scale).toDouble())
            .toList(growable: false);
      }
    } catch (_) {
      // ignore
    }
    return rawVec.map((e) => (e as num).toDouble()).toList(growable: false);
  }

  /// Synthetic benchmark (no file I/O): measures pure interpreter latency.
  /// Intended for "max performance" checks.
  ///
  /// ウォームアップ ([warmupRuns] 回) 後に [runs] 回推論を実行し、
  /// 各回のレイテンシ (ms) から統計値を計算して返す。
  /// GPU推論中にクラッシュした場合は、取得済みのサンプルで部分結果を返す。
  @override
  Future<BenchmarkStats> runSyntheticBenchmark({
    int warmupRuns = 20,
    int runs = 200,
  }) async {
    if (_interpreter == null) {
      await initialize();
    }
    if (_interpreter == null) {
      return computeBenchmarkStats(const []);
    }

    final input = _createZeroInput();
    if (input == null) {
      return computeBenchmarkStats(const []);
    }

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    int outputSize = 1;
    for (final s in outputShape) {
      outputSize *= s;
    }

    dynamic output;
    final type = _outputTensorType ?? outputTensor.type;
    if (type == TensorType.float32) {
      output = List.filled(outputSize, 0.0).reshape(outputShape);
    } else {
      output = List.filled(outputSize, 0).reshape(outputShape);
    }

    // Warmup — errors here may indicate GPU incompatibility.
    try {
      for (int i = 0; i < warmupRuns; i++) {
        _interpreter!.run(input, output);
      }
    } catch (e) {
      debugPrint('Benchmark warmup failed at $_actualDevice: $e');
      throw Exception('ウォームアップ中にエラー ($_actualDevice): $e');
    }

    // We do the actual benchmark runs with a yield every 50 iterations
    // so the UI thread stays responsive and setState can safely be called.
    final samplesMs = <double>[];
    final clock = Stopwatch()..start();
    try {
      for (int i = 0; i < runs; i++) {
        final t0 = clock.elapsedMicroseconds;
        _interpreter!.run(input, output);
        final t1 = clock.elapsedMicroseconds;
        samplesMs.add((t1 - t0) / 1000.0);

        // Yield periodically to keep UI responsive
        if (i % 50 == 49) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (e) {
      debugPrint('Benchmark run failed after ${samplesMs.length} samples: $e');
      // Return partial results if we got at least a few samples
      if (samplesMs.length >= 5) {
        return computeBenchmarkStats(samplesMs);
      }
      throw Exception('推論ベンチマーク中にエラー ($_actualDevice, '
          '${samplesMs.length}/$runs 完了): $e');
    }

    return computeBenchmarkStats(samplesMs);
  }
}
