# GPU Inference Testing Guide

This guide provides instructions for testing the GPU inference implementation across different platforms.

## Testing on Windows

### Prerequisites
- Windows 10/11 with DirectX 12
- GPU with DirectML support (NVIDIA, AMD, or Intel)
- ONNX Runtime DirectML DLL (see WINDOWS_DIRECTML_SETUP.md)

### Test Cases

#### TC1: DirectML Availability Detection
**Steps**:
1. Launch the app
2. Check console output for GPU capabilities

**Expected Output**:
```
=== GPU Capabilities ===
Platform: windows
TFLite GPU: false
DirectML: true
NNAPI: false
CoreML: false
TFLite devices: CPU
ONNX devices: CPU, XNNPACK, DirectML
=======================
```

#### TC2: ONNX DirectML Engine Selection
**Steps**:
1. Select "ONNX DirectML (Windows)" engine
2. Device dropdown should show: CPU, XNNPACK, DirectML
3. Select "DirectML" device
4. Click "パフォーマンスチェック" (Performance Check)

**Expected Result**:
- Engine initializes successfully
- Name shows "ModelName (ONNX-DirectML)" or "(ONNX-XNNPACK)" as fallback
- Inference completes without errors

#### TC3: DirectML Fallback to XNNPACK
**Steps**:
1. Rename or remove DirectML DLL
2. Select ONNX DirectML engine with DirectML device
3. Run performance check

**Expected Result**:
- Console shows "DirectML requested but not directly supported"
- Falls back to XNNPACK
- Engine name shows "(ONNX-XNNPACK)"

#### TC4: Performance Comparison
**Steps**:
1. Run performance check with CPU device (100 iterations)
2. Note average latency (ms)
3. Run performance check with XNNPACK device
4. Note average latency (ms)
5. Compare results

**Expected Result**:
- XNNPACK should be 2-3x faster than CPU
- DirectML (when fully implemented) should be 5-10x faster

## Testing on Android

### Prerequisites
- Android device with GPU
- Android 8.0+ for NNAPI support

### Test Cases

#### TC5: TFLite GPU Availability
**Steps**:
1. Launch app on Android device
2. Check console for GPU capabilities

**Expected Output**:
```
=== GPU Capabilities ===
Platform: android
TFLite GPU: true
DirectML: false
NNAPI: true
CoreML: false
TFLite devices: CPU, GPU
ONNX devices: CPU, XNNPACK, NNAPI
=======================
```

#### TC6: TFLite GPU Delegate
**Steps**:
1. Select "TFLite (CPU/GPU)" engine
2. Select "GPU" device
3. Run performance check

**Expected Result**:
- Engine name shows "ModelName (TFLite-GPU)"
- GPU inference 3-5x faster than CPU
- No errors during inference

#### TC7: ONNX NNAPI
**Steps**:
1. Select "ONNX Runtime" engine
2. Select "NNAPI" device
3. Run performance check

**Expected Result**:
- Engine name shows "ModelName (ONNX-NNAPI)"
- Inference completes successfully
- Performance similar to or better than CPU

#### TC8: GPU Fallback on Android
**Steps**:
1. Run on Android emulator (no GPU support)
2. Select TFLite with GPU device
3. Run performance check

**Expected Result**:
- Console shows "GPU delegate failed, falling back to CPU"
- Engine name shows "(TFLite-CPU)"
- Inference completes successfully

## Testing on iOS/macOS

### Prerequisites
- macOS with Apple Silicon or Intel GPU
- iOS device with A-series chip

### Test Cases

#### TC9: CoreML Availability
**Steps**:
1. Launch app
2. Check console for capabilities

**Expected Output**:
```
=== GPU Capabilities ===
Platform: macos (or ios)
TFLite GPU: true
DirectML: false
NNAPI: false
CoreML: true
=======================
```

#### TC10: ONNX CoreML
**Steps**:
1. Select "ONNX Runtime" engine
2. Select "CoreML" device
3. Run performance check

**Expected Result**:
- Engine name shows "(ONNX-CoreML)"
- Inference uses Apple Neural Engine
- Best performance on Apple devices

## Cross-Platform Test Cases

#### TC11: Device Selection Persistence
**Steps**:
1. Select TFLite engine with GPU device
2. Switch to ONNX engine
3. Device should reset to available device for ONNX
4. Switch back to TFLite
5. Device selection should be retained if available

**Expected Result**:
- Device selection updates when changing engines
- No crashes or invalid device selections

#### TC12: Error Handling
**Steps**:
1. Select an engine with GPU device
2. Remove model files
3. Try to initialize engine

**Expected Result**:
- Clear error message shown
- App doesn't crash
- Can recover by downloading model

#### TC13: Benchmark with Different Devices
**Steps**:
1. Load a test set
2. Run benchmark with CPU device
3. Note accuracy and performance
4. Run benchmark with GPU device
5. Compare results

**Expected Result**:
- Accuracy should be identical (±0.001)
- GPU should be significantly faster
- Both complete successfully

## Resource Management Tests

#### TC14: Multiple Engine Initialization
**Steps**:
1. Initialize TFLite engine
2. Run performance check
3. Go back and select ONNX engine
4. Initialize and run performance check
5. Repeat 3-4 times

**Expected Result**:
- No memory leaks
- Each initialization succeeds
- No "resource already released" errors

#### TC15: Rapid Engine Switching
**Steps**:
1. Quickly switch between engines multiple times
2. Initialize each engine
3. Dispose and create new ones

**Expected Result**:
- No crashes
- Proper resource cleanup
- No OrtEnv singleton errors

## Performance Benchmarks

### Expected Performance Ranges

#### Mobile Devices
| Device | Model | CPU (ms) | GPU (ms) | Speedup |
|--------|-------|----------|----------|---------|
| Pixel 6 | MobileNetV2 | ~50 | ~15 | 3.3x |
| iPhone 13 | MobileNetV2 | ~40 | ~10 | 4.0x |
| Galaxy S21 | MobileNetV2 | ~45 | ~12 | 3.7x |

#### Desktop
| Device | Model | CPU (ms) | XNNPACK (ms) | DirectML (ms) |
|--------|-------|----------|--------------|---------------|
| i7 + RTX 3060 | MobileNetV2 | ~30 | ~15 | ~5* |
| Ryzen 5 + RX 580 | MobileNetV2 | ~35 | ~18 | ~7* |

*Note: DirectML performance pending full implementation

## Automated Testing

### Unit Tests (Future Implementation)

```dart
// Example test structure
void main() {
  group('GpuCapabilityChecker', () {
    test('detects platform correctly', () {
      final checker = GpuCapabilityChecker.instance;
      expect(checker.availableTfliteDevices.contains('CPU'), true);
    });
  });

  group('OnnxEngine', () {
    test('falls back to CPU on GPU failure', () async {
      final engine = OnnxEngine(
        modelName: 'test',
        modelPath: 'invalid',
        device: 'GPU',
      );
      // Should not throw, should fallback
      await expectLater(engine.initialize(), completes);
    });
  });
}
```

## Reporting Issues

When reporting issues, please include:

1. **Platform Info**
   - OS version (Windows 11, Android 12, etc.)
   - Device model
   - GPU model

2. **Console Logs**
   - Full GPU capabilities log
   - Any error messages
   - Engine initialization logs

3. **Reproduction Steps**
   - Exact steps to reproduce
   - Selected engine and device
   - Expected vs actual behavior

4. **Performance Data**
   - Latency numbers from performance check
   - Comparison with CPU baseline
   - Screenshot of results

## Success Criteria

The implementation is considered successful when:

✅ All platforms detect available GPU capabilities correctly
✅ Device selection UI shows only available devices
✅ GPU initialization succeeds or falls back gracefully
✅ Performance improvements are measurable on GPU
✅ No resource leaks or crashes during normal use
✅ Error messages are clear and actionable
