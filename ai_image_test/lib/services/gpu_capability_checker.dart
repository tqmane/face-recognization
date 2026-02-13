import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to check GPU availability on different platforms.
class GpuCapabilityChecker {
  GpuCapabilityChecker._();
  static final GpuCapabilityChecker instance = GpuCapabilityChecker._();

  /// Check if TFLite GPU is available on current platform.
  bool get isTfliteGpuAvailable {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Check if ONNX DirectML is available (Windows only).
  bool get isDirectMLAvailable {
    return Platform.isWindows;
  }

  /// Check if ONNX NNAPI is available (Android only).
  bool get isNNAPIAvailable {
    return Platform.isAndroid;
  }

  /// Check if CoreML is available (Apple platforms).
  bool get isCoreMLAvailable {
    return Platform.isMacOS || Platform.isIOS;
  }

  /// Get list of available TFLite devices for current platform.
  List<String> get availableTfliteDevices {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return ['CPU', 'GPU'];
    }
    return ['CPU'];
  }

  /// Get list of available ONNX devices for current platform.
  List<String> get availableOnnxDevices {
    final devices = ['CPU', 'XNNPACK'];
    
    if (Platform.isMacOS || Platform.isIOS) {
      devices.add('CoreML');
    } else if (Platform.isAndroid) {
      devices.add('NNAPI');
    } else if (Platform.isWindows) {
      devices.add('DirectML');
    }
    
    return devices;
  }

  /// Check if a specific device type is supported for TFLite.
  bool isTfliteDeviceSupported(String device) {
    return availableTfliteDevices.contains(device);
  }

  /// Check if a specific device type is supported for ONNX.
  bool isOnnxDeviceSupported(String device) {
    return availableOnnxDevices.contains(device);
  }

  /// Get recommended device for TFLite on current platform.
  String get recommendedTfliteDevice {
    if (isTfliteGpuAvailable) {
      return 'GPU';
    }
    return 'CPU';
  }

  /// Get recommended device for ONNX on current platform.
  String get recommendedOnnxDevice {
    if (Platform.isMacOS || Platform.isIOS) {
      return 'CoreML';
    } else if (Platform.isAndroid) {
      return 'NNAPI';
    } else if (Platform.isWindows) {
      return 'DirectML';
    }
    return 'XNNPACK';
  }

  /// Get a human-readable description of GPU capabilities.
  String get capabilitiesDescription {
    final caps = <String>[];
    
    if (isTfliteGpuAvailable) {
      caps.add('TFLite GPU');
    }
    if (isDirectMLAvailable) {
      caps.add('DirectML');
    }
    if (isNNAPIAvailable) {
      caps.add('NNAPI');
    }
    if (isCoreMLAvailable) {
      caps.add('CoreML');
    }
    
    if (caps.isEmpty) {
      return 'CPU only';
    }
    return caps.join(', ');
  }

  /// Log current platform capabilities.
  void logCapabilities() {
    debugPrint('=== GPU Capabilities ===');
    debugPrint('Platform: ${Platform.operatingSystem}');
    debugPrint('TFLite GPU: $isTfliteGpuAvailable');
    debugPrint('DirectML: $isDirectMLAvailable');
    debugPrint('NNAPI: $isNNAPIAvailable');
    debugPrint('CoreML: $isCoreMLAvailable');
    debugPrint('TFLite devices: ${availableTfliteDevices.join(", ")}');
    debugPrint('ONNX devices: ${availableOnnxDevices.join(", ")}');
    debugPrint('=======================');
  }
}
