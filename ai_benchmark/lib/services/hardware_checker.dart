import 'dart:io';
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart';

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

    // Check NNAPI (Android only) - Disabled due to API instability
    /*
    if (Platform.isAndroid) {
      try {
        final options = InterpreterOptions();
        // options.useNnApi = true; // Not supported in 0.10.4
        // final interpreter = await Interpreter.fromFile(file, options: options);
        // interpreter.close();
        // status['NNAPI'] = true;
      } catch (e) {
        print('NNAPI Check failed: $e');
        status['NNAPI'] = false;
      }
    }
    */

    return status;
  }
}
