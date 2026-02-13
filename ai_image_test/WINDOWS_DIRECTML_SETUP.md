# Windows DirectML Setup Guide

## Prerequisites for DirectML Support

To use GPU acceleration on Windows via DirectML, you need to install the ONNX Runtime with DirectML support.

### Option 1: ONNX Runtime DirectML DLL (Recommended for Production)

1. **Download ONNX Runtime DirectML**
   - Visit [ONNX Runtime Releases](https://github.com/microsoft/onnxruntime/releases)
   - Download the latest `onnxruntime-win-x64-gpu-*.zip` (includes DirectML)
   - Or download `onnxruntime-directml-*.zip` for DirectML-specific build

2. **Extract and Place DLLs**
   ```
   Extract the zip file and copy the following files to your Windows PATH or app directory:
   - onnxruntime.dll (or onnxruntime-directml.dll)
   - DirectML.dll
   ```

3. **Add to System PATH**
   - Option A: Copy DLLs to `C:\Windows\System32`
   - Option B: Add the extracted directory to your System PATH
   - Option C: Place DLLs in the same directory as your Flutter app executable

### Option 2: Python ONNX Runtime (Alternative for Testing)

If you have Python installed, you can use the Python ONNX Runtime as a backend:

```bash
pip install onnxruntime-directml
```

Then use a Python bridge or subprocess to handle inference (requires additional implementation).

## Verifying DirectML Support

### Check GPU Availability

1. **Using Windows Device Manager**
   - Open Device Manager (Win + X → Device Manager)
   - Expand "Display adapters"
   - Verify your GPU is listed and enabled

2. **Using DirectX Diagnostic Tool**
   ```
   Win + R → dxdiag
   ```
   - Go to "Display" tab
   - Check DirectX version (should be 12 or higher for DirectML)

3. **Using App Logs**
   - Run the ai_image_test app
   - Check console output for:
     ```
     === GPU Capabilities ===
     Platform: windows
     DirectML: true
     ```

## Supported GPUs

DirectML supports a wide range of GPUs:
- **NVIDIA**: GeForce GTX 900 series and newer
- **AMD**: Radeon RX 400 series and newer
- **Intel**: Intel HD Graphics 600 series and newer
- Requires DirectX 12 support

## Troubleshooting

### DirectML Not Available

**Symptom**: App shows "DirectML not available" or falls back to CPU/XNNPACK

**Solutions**:
1. Verify DLLs are in PATH
   ```cmd
   where onnxruntime.dll
   where DirectML.dll
   ```

2. Check DirectX version
   ```cmd
   dxdiag
   ```
   - Should be DirectX 12 or higher

3. Update GPU drivers
   - NVIDIA: [nvidia.com/drivers](https://www.nvidia.com/drivers)
   - AMD: [amd.com/support](https://www.amd.com/support)
   - Intel: [intel.com/graphics](https://www.intel.com/content/www/us/en/download-center/home.html)

### Performance Issues

**Symptom**: GPU inference slower than expected

**Solutions**:
1. Check GPU utilization
   - Use Task Manager (Performance tab → GPU)
   - GPU should show activity during inference

2. Verify DirectML is being used
   - Check app logs for "ONNX-DirectML" or "ONNX-XNNPACK"
   - DirectML should show better performance than CPU

3. Model optimization
   - Ensure model is in ONNX format (not TFLite)
   - Use fp16 models for better GPU performance (if supported)

### DLL Load Errors

**Symptom**: "Failed to load onnxruntime.dll"

**Solutions**:
1. Install Visual C++ Redistributables
   - Download from [Microsoft](https://aka.ms/vs/17/release/vc_redist.x64.exe)

2. Check DLL architecture
   - Use 64-bit DLLs for 64-bit Windows
   - Match architecture with your Flutter build

## Current Limitations

1. **Package Limitation**: The current Dart `onnxruntime` package (v1.4.1) doesn't expose DirectML execution provider directly
   - App currently uses XNNPACK as an optimized fallback
   - Full DirectML support requires custom FFI implementation or package update

2. **Workaround**: The implementation checks for DirectML availability via FFI but falls back to XNNPACK for actual inference

## Future Implementation

To achieve full DirectML support, one of these approaches is needed:

1. **Custom FFI Bindings**
   - Implement complete FFI bindings to ONNX Runtime C API
   - Manually configure DirectML execution provider
   - Handle memory management and tensor operations

2. **Package Update**
   - Wait for onnxruntime Dart package to add DirectML support
   - Update implementation when available

3. **Native Plugin**
   - Create a Flutter platform channel
   - Implement DirectML inference in native Windows C++ code
   - Bridge results back to Dart

## Performance Comparison

Expected performance improvements with DirectML on Windows:

| Device       | Relative Performance |
|--------------|---------------------|
| CPU          | 1x (baseline)       |
| XNNPACK      | 2-3x faster        |
| DirectML GPU | 5-10x faster       |

Actual performance varies based on:
- GPU model and memory
- Model size and complexity
- Input image size
- Batch size

## Additional Resources

- [DirectML Overview](https://docs.microsoft.com/en-us/windows/ai/directml/dml)
- [ONNX Runtime Documentation](https://onnxruntime.ai/docs/)
- [DirectML Performance Guide](https://docs.microsoft.com/en-us/windows/ai/directml/dml-performance)
