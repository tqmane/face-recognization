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
  String get name => '$_modelName ($device)';

  /// Check if GPU acceleration is available on the current platform
  static bool get isGpuAvailable {
    // GPU delegates available on: Android (OpenCL/OpenGL), iOS/macOS (Metal)
    // Not available on: Windows, Linux (TFLite C API doesn't include GPU delegate)
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Get available device options for the current platform
  static List<String> get availableDevices {
    if (Platform.isAndroid) {
      return ['CPU', 'GPU', 'NNAPI'];
    } else if (Platform.isIOS || Platform.isMacOS) {
      return ['CPU', 'GPU'];
    } else {
      // Windows, Linux - only CPU available via TFLite C API
      return ['CPU'];
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();
      
      // Hardware Acceleration setup
      if (Platform.isAndroid) {
        if (device == 'GPU') {
          // Use default GPU Delegate settings for compatibility
          try {
            _delegate = GpuDelegateV2();
            options.addDelegate(_delegate!);
            debugPrint('Using Android GPU Delegate (OpenCL/OpenGL)');
          } catch (e) {
            debugPrint('Failed to create GpuDelegateV2: $e');
          }
        } else if (device == 'NNAPI') {
          // NNAPI support varies by tflite_flutter version.
          // Trying NnApiDelegate if available, otherwise fallback.
          try {
             // options.useNnApi = true; // Removed: Not supported in 0.10.4
             // _delegate = NnApiDelegate(); // Check if this exists at runtime/compile time
             // options.addDelegate(_delegate!);
             debugPrint('NNAPI is currently disabled due to API compatibility issues.');
          } catch (e) {
             debugPrint('NNAPI not supported: $e');
          }
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        if (device == 'GPU') {
           try {
             // Metal Delegate for iOS/macOS
             _delegate = GpuDelegate();
             options.addDelegate(_delegate!);
             debugPrint('Using Metal GPU Delegate');
           } catch (e) {
             debugPrint('Failed to create GpuDelegate (Metal): $e');
           }
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        if (device == 'GPU') {
          // GPU delegate is not available for Windows/Linux in TFLite C API
          debugPrint('GPU delegate not available on ${Platform.operatingSystem}. Using CPU with $threads threads.');
        }
      }
      
      options.threads = threads;

      // Load from Asset or File
      if (File(_modelPath).isAbsolute) {
        _interpreter = await Future.sync(
          () => Interpreter.fromFile(File(_modelPath), options: options),
        );
      } else {
        _interpreter = await Future.sync(
          () => Interpreter.fromAsset(_modelPath, options: options),
        );
      }
      
      debugPrint('Loaded TFLite model: $_modelName from $_modelPath on $device');

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      _inputTensorType = inputTensor.type;
      _outputTensorType = outputTensor.type;
      _inputShape = inputTensor.shape;

      // Warmup
      final warmupInput = _createZeroInput();
      if (warmupInput != null) {
        _runInference(warmupInput);
      }
      
    } catch (e) {
      debugPrint('Failed to load TFLite model on $device: $e');
      throw Exception('Failed to initialize model on $device: $e');
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

    // Warmup
    for (int i = 0; i < warmupRuns; i++) {
      _interpreter!.run(input, output);
    }

    final samplesMs = <double>[];
    final clock = Stopwatch()..start();
    for (int i = 0; i < runs; i++) {
      final t0 = clock.elapsedMicroseconds;
      _interpreter!.run(input, output);
      final t1 = clock.elapsedMicroseconds;
      samplesMs.add((t1 - t0) / 1000.0);
    }

    return computeBenchmarkStats(samplesMs);
  }
}
