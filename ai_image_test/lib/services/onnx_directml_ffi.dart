import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// FFI bindings for ONNX Runtime with DirectML support.
/// 
/// This provides low-level bindings to the ONNX Runtime C API
/// with DirectML execution provider for GPU acceleration on Windows.
class OnnxRuntimeDirectML {
  static const String _libName = 'onnxruntime';
  
  late final ffi.DynamicLibrary _lib;
  bool _initialized = false;

  /// Initialize the DirectML library.
  /// Returns true if successful, false otherwise.
  bool initialize() {
    if (_initialized) return true;
    
    try {
      // Try to load ONNX Runtime DLL with DirectML support
      // User needs to have onnxruntime-directml.dll in the path
      if (Platform.isWindows) {
        try {
          _lib = ffi.DynamicLibrary.open('$_libName.dll');
        } catch (e) {
          debugPrint('Failed to load onnxruntime.dll, trying onnxruntime-directml.dll: $e');
          _lib = ffi.DynamicLibrary.open('onnxruntime-directml.dll');
        }
      } else {
        throw UnsupportedError('DirectML is only supported on Windows');
      }
      
      _initialized = true;
      debugPrint('ONNX Runtime DirectML library loaded successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to load ONNX Runtime DirectML library: $e');
      return false;
    }
  }

  /// Check if DirectML is available on this system.
  static bool isAvailable() {
    if (!Platform.isWindows) return false;
    
    try {
      final lib = OnnxRuntimeDirectML();
      return lib.initialize();
    } catch (e) {
      debugPrint('DirectML not available: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _initialized = false;
  }
}
