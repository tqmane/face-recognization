import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';

// FFI type definitions for OrtSessionOptions_AppendExecutionProvider_DML
// C signature:
//   OrtStatus* OrtSessionOptions_AppendExecutionProvider_DML(
//       OrtSessionOptions* options, int device_id)
typedef _AppendDmlNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Void> options, ffi.Int32 deviceId);
typedef _AppendDmlDart = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi.Void> options, int deviceId);

/// FFI bindings for ONNX Runtime with DirectML support.
///
/// This provides low-level bindings to the ONNX Runtime C API
/// with DirectML execution provider for GPU acceleration on Windows.
///
/// **Requirements for DirectML support:**
/// The standard `onnxruntime` Dart package bundles `onnxruntime.dll` which
/// does NOT include DirectML.  To enable GPU acceleration via DirectML you
/// need the DirectML-enabled DLL (e.g. `onnxruntime-directml.dll` from the
/// Microsoft.ML.OnnxRuntime.DirectML NuGet package) placed next to the app
/// executable, OR a Dart package that bundles that DLL.  As of onnxruntime
/// v1.4.1 there is no separate `onnxruntime_directml` pub.dev package, so
/// the DLL swap is the recommended approach on Windows.
class OnnxRuntimeDirectML {
  static const String _libName = 'onnxruntime';

  late final ffi.DynamicLibrary _lib;
  bool _initialized = false;
  _AppendDmlDart? _appendDml;

  /// Initialize the DirectML library.
  /// Returns true if the DirectML-capable DLL was loaded successfully.
  bool initialize() {
    if (_initialized) return true;

    if (!Platform.isWindows) {
      throw UnsupportedError('DirectML is only supported on Windows');
    }

    try {
      // Prefer the DirectML-enabled DLL; fall back to the standard one so
      // that the app still runs (without GPU acceleration) when the DirectML
      // DLL is absent.
      try {
        _lib = ffi.DynamicLibrary.open('onnxruntime-directml.dll');
        debugPrint('OnnxRuntimeDirectML: loaded onnxruntime-directml.dll');
      } catch (_) {
        _lib = ffi.DynamicLibrary.open('$_libName.dll');
        debugPrint('OnnxRuntimeDirectML: DirectML DLL not found, loaded standard onnxruntime.dll');
      }

      // Try to resolve the DirectML provider function.
      // This will succeed only when onnxruntime-directml.dll is loaded.
      try {
        final fn = _lib.lookup<ffi.NativeFunction<_AppendDmlNative>>(
            'OrtSessionOptions_AppendExecutionProvider_DML');
        _appendDml = fn.asFunction<_AppendDmlDart>();
        debugPrint('OnnxRuntimeDirectML: OrtSessionOptions_AppendExecutionProvider_DML resolved');
      } catch (e) {
        debugPrint('OnnxRuntimeDirectML: AppendExecutionProvider_DML not found '
            '(standard DLL without DirectML): $e');
        _appendDml = null;
      }

      _initialized = true;
      return _appendDml != null; // true only if DirectML is really available
    } catch (e) {
      debugPrint('OnnxRuntimeDirectML: failed to load ONNX Runtime library: $e');
      return false;
    }
  }

  /// Returns true if the DirectML execution provider function was resolved.
  bool get isDirectMLFunctionAvailable => _initialized && _appendDml != null;

  /// Attempt to append the DirectML execution provider to the given raw
  /// OrtSessionOptions* pointer.
  ///
  /// Returns true on success, false if DirectML is not available or the call
  /// fails.  [optionsPtr] must be the raw `OrtSessionOptions*` obtained from
  /// the underlying ONNX Runtime C API.
  bool appendExecutionProviderDML(
      ffi.Pointer<ffi.Void> optionsPtr, int deviceId) {
    if (_appendDml == null) return false;
    try {
      final status = _appendDml!(optionsPtr, deviceId);
      // A null status pointer means success in the ORT C API.
      return status == ffi.nullptr;
    } catch (e) {
      debugPrint('OnnxRuntimeDirectML: appendExecutionProvider_DML failed: $e');
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
      debugPrint('OnnxRuntimeDirectML: not available: $e');
      return false;
    }
  }

  /// Dispose resources.
  void dispose() {
    _initialized = false;
    _appendDml = null;
  }
}
