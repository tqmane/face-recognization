import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

class HardwareChecker {
  Future<Map<String, bool>> checkAvailability(String modelPath) async {
    final status = {
      'CPU': true, // Always true
      'GPU': false,
      'NNAPI': false,
    };
    
    final file = File(modelPath);
    if (!await file.exists()) {
      // Cannot check without a model
      return status;
    }

    // Check GPU
    try {
      if (Platform.isAndroid) {
        final options = InterpreterOptions();
        options.addDelegate(GpuDelegateV2());
        final interpreter = await Interpreter.fromFile(file, options: options);
        interpreter.close();
        status['GPU'] = true;
      } else if (Platform.isIOS) {
        final options = InterpreterOptions();
        options.addDelegate(GpuDelegate());
        final interpreter = await Interpreter.fromFile(file, options: options);
        interpreter.close();
        status['GPU'] = true;
      }
    } catch (e) {
      print('GPU Check failed: $e');
      status['GPU'] = false;
    }

    // Check NNAPI (Android only)
    if (Platform.isAndroid) {
      try {
        final options = InterpreterOptions();
        options.useNnApi = true;
        final interpreter = await Interpreter.fromFile(file, options: options);
        interpreter.close();
        status['NNAPI'] = true;
      } catch (e) {
        print('NNAPI Check failed: $e');
        status['NNAPI'] = false;
      }
    }

    return status;
  }
}