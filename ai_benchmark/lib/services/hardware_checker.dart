import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
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
      return status;
    }

    // Check GPU
    try {
      if (Platform.isAndroid) {
        final options = InterpreterOptions();
        options.addDelegate(GpuDelegateV2());
        final interpreter = await Future.sync(
          () => Interpreter.fromFile(file, options: options),
        );
        interpreter.close();
        status['GPU'] = true;
      } else if (Platform.isIOS) {
        final options = InterpreterOptions();
        options.addDelegate(GpuDelegate());
        final interpreter = await Future.sync(
          () => Interpreter.fromFile(file, options: options),
        );
        interpreter.close();
        status['GPU'] = true;
      }
    } catch (e) {
      debugPrint('GPU Check failed: $e');
      status['GPU'] = false;
    }

    // NNAPI (Android) is intentionally disabled due to API instability.

    return status;
  }
}
