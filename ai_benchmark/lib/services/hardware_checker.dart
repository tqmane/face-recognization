import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class HardwareChecker {
  /// Check which accelerators are available for TFLite models.
  ///
  /// [modelPath] must point to a .tflite file on disk. If the file does not
  /// exist the method returns CPU-only.
  Future<Map<String, bool>> checkAvailability(String modelPath) async {
    final status = {
      'CPU': true, // Always true
      'GPU': false,
    };
    
    final file = File(modelPath);
    if (!await file.exists()) {
      return status;
    }

    // GPU check per platform
    if (Platform.isAndroid) {
      status['GPU'] = await _checkAndroidGpu(file);
    } else if (Platform.isIOS || Platform.isMacOS) {
      status['GPU'] = await _checkMetalGpu(file);
    }
    // Windows/Linux: TFLite GPU delegate is NOT available via the C API.
    // GPU acceleration on these platforms requires ONNX Runtime (see OnnxEngine).

    return status;
  }

  /// Try to create an interpreter with GpuDelegateV2 on Android.
  ///
  /// Uses `isPrecisionLossAllowed: true` to match the options used by
  /// [TfliteEngine] for maximum compatibility.
  Future<bool> _checkAndroidGpu(File modelFile) async {
    Interpreter? interpreter;
    Delegate? delegate;
    try {
      final options = InterpreterOptions();
      delegate = GpuDelegateV2(
        options: GpuDelegateOptionsV2(
          isPrecisionLossAllowed: true,
        ),
      );
      options.addDelegate(delegate);
      interpreter = Interpreter.fromFile(modelFile, options: options);

      // Try a dummy run to ensure the delegate actually works at inference time.
      final inputTensor = interpreter.getInputTensor(0);
      final shape = inputTensor.shape;
      int size = 1;
      for (final s in shape) {
        size *= s;
      }
      final input = inputTensor.type == TensorType.float32
          ? List.filled(size, 0.0).reshape(shape)
          : List.filled(size, 0).reshape(shape);

      final outputTensor = interpreter.getOutputTensor(0);
      final outShape = outputTensor.shape;
      int outSize = 1;
      for (final s in outShape) {
        outSize *= s;
      }
      final output = outputTensor.type == TensorType.float32
          ? List.filled(outSize, 0.0).reshape(outShape)
          : List.filled(outSize, 0).reshape(outShape);

      interpreter.run(input, output);

      debugPrint('GPU Check (Android): OK');
      return true;
    } catch (e) {
      debugPrint('GPU Check (Android) failed: $e');
      return false;
    } finally {
      interpreter?.close();
      delegate?.delete();
    }
  }

  /// Try to create an interpreter with Metal GpuDelegate on iOS / macOS.
  Future<bool> _checkMetalGpu(File modelFile) async {
    Interpreter? interpreter;
    Delegate? delegate;
    try {
      final options = InterpreterOptions();
      delegate = GpuDelegate();
      options.addDelegate(delegate);
      interpreter = Interpreter.fromFile(modelFile, options: options);

      // Try a dummy run.
      final inputTensor = interpreter.getInputTensor(0);
      final shape = inputTensor.shape;
      int size = 1;
      for (final s in shape) {
        size *= s;
      }
      final input = inputTensor.type == TensorType.float32
          ? List.filled(size, 0.0).reshape(shape)
          : List.filled(size, 0).reshape(shape);

      final outputTensor = interpreter.getOutputTensor(0);
      final outShape = outputTensor.shape;
      int outSize = 1;
      for (final s in outShape) {
        outSize *= s;
      }
      final output = outputTensor.type == TensorType.float32
          ? List.filled(outSize, 0.0).reshape(outShape)
          : List.filled(outSize, 0).reshape(outShape);

      interpreter.run(input, output);

      debugPrint('GPU Check (Metal): OK');
      return true;
    } catch (e) {
      debugPrint('GPU Check (Metal) failed: $e');
      return false;
    } finally {
      interpreter?.close();
      delegate?.delete();
    }
  }

  /// Return a list of available device strings for the current platform,
  /// considering both TFLite and ONNX capabilities.
  ///
  /// This is a convenience helper that does **not** probe actual hardware. It
  /// returns the *possible* device options for UI dropdowns.
  static List<String> availableDevicesForPlatform({bool hasOnnx = false, bool hasTflite = false}) {
    final devices = <String>{'CPU'};

    if (hasTflite) {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        devices.add('GPU');
      }
    }

    if (hasOnnx) {
      if (Platform.isMacOS || Platform.isIOS) {
        devices.add('CoreML');
      }
      if (Platform.isAndroid) {
        devices.add('XNNPACK');
      }
      if (Platform.isWindows || Platform.isLinux) {
        devices.add('XNNPACK');
      }
    }

    return devices.toList();
  }
}
