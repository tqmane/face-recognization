import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'inference_engine.dart';

class TfliteEngine implements InferenceEngine {
  final String _modelName;
  final String _modelPath;
  final int _inputSize;
  final String device;
  Interpreter? _interpreter;
  Delegate? _delegate;
  
  TfliteEngine({
    required String modelName, 
    required String modelPath,
    int inputSize = 224,
    this.device = 'CPU', bool useGpu = false
  }) : _modelName = modelName,
       _modelPath = modelPath,
       _inputSize = inputSize;

  @override
  String get name => '$_modelName ($device)';

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
          } catch (e) {
            print('Failed to create GpuDelegateV2: $e');
          }
        } else if (device == 'NNAPI') {
          // NNAPI support varies by tflite_flutter version.
          // Trying NnApiDelegate if available, otherwise fallback.
          try {
             // options.useNnApi = true; // Removed: Not supported in 0.10.4
             // _delegate = NnApiDelegate(); // Check if this exists at runtime/compile time
             // options.addDelegate(_delegate!);
             print('NNAPI is currently disabled due to API compatibility issues.');
          } catch (e) {
             print('NNAPI not supported: $e');
          }
        }
      } else if (Platform.isIOS) {
        if (device == 'GPU') {
           try {
             // Metal Delegate (GpuDelegate on iOS)
             _delegate = GpuDelegate();
             options.addDelegate(_delegate!);
           } catch (e) {
             print('Failed to create GpuDelegate (Metal): $e');
           }
        }
      }
      
      options.threads = 4;

      // Load from Asset or File
      if (File(_modelPath).isAbsolute) {
        _interpreter = await Interpreter.fromFile(File(_modelPath), options: options);
      } else {
        _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      }
      
      print('Loaded TFLite model: $_modelName from $_modelPath on $device');
      
      // Warmup
      _runInference(List.filled(_inputSize * _inputSize * 3, 0).reshape([1, _inputSize, _inputSize, 3]));
      
    } catch (e) {
      print('Failed to load TFLite model on $device: $e');
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

  List<dynamic>? _runInference(List<dynamic> input) {
    if (_interpreter == null) return null;
    
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape; 
    
    int outputSize = 1;
    for (var s in outputShape) {
      outputSize *= s;
    }
    
    var output = List.filled(outputSize, 0).reshape(outputShape);
    _interpreter!.run(input, output);
    
    return output[0];
  }

  Future<List<dynamic>?> _preprocessImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
      
      final input = List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        });
      });
      
      return [input];
    } catch (e) {
      print('Error preprocessing image: $e');
      return null;
    }
  }

  double _cosineSimilarity(List<dynamic>? vec1, List<dynamic>? vec2) {
    if (vec1 == null || vec2 == null) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      double v1 = (vec1[i] as num).toDouble();
      double v2 = (vec2[i] as num).toDouble();
      
      dotProduct += v1 * v2;
      normA += v1 * v1;
      normB += v2 * v2;
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
