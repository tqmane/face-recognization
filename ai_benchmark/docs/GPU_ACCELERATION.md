# GPU Acceleration Guide for AI Benchmark

This guide explains how to enable GPU acceleration on different platforms.

## Summary

| Platform | Runtime | GPU Provider | Setup Required |
|----------|---------|--------------|----------------|
| **Android** | TFLite | OpenCL/OpenGL | None (built-in) |
| **iOS** | TFLite | Metal | None (built-in) |
| **macOS** | TFLite | Metal | None (built-in) |
| **Windows** | ONNX Runtime | DirectML | Model conversion |
| **Linux** | ONNX Runtime | CUDA | Model conversion + CUDA |

## Mobile Platforms (Android/iOS)

GPU acceleration works out of the box using TensorFlow Lite.

- **Android**: Uses `GpuDelegateV2` (OpenCL/OpenGL ES)
- **iOS**: Uses `GpuDelegate` (Metal)
- **macOS**: Uses `GpuDelegate` (Metal)

Just select "GPU" in the device dropdown.

## Windows (DirectML)

Windows uses ONNX Runtime with DirectML, which supports AMD, Intel, and NVIDIA GPUs.

### Step 1: Convert TFLite Model to ONNX

```bash
# Install conversion tools
pip install tf2onnx tensorflow onnx

# Convert model
python tools/convert_tflite_to_onnx.py mobilenet_v2.tflite mobilenet_v2.onnx
```

### Step 2: Download DirectML Runtime

The `onnxruntime` Flutter package includes DirectML support. No additional setup needed.

### Step 3: Use in App

Place `.onnx` models in `assets/models/` and select "DirectML" as the device.

## Linux (CUDA)

Linux uses ONNX Runtime with CUDA for NVIDIA GPUs.

### Prerequisites

1. **NVIDIA GPU** with CUDA support
2. **CUDA Toolkit** 11.x or 12.x
3. **cuDNN** library

### Step 1: Install CUDA

```bash
# Ubuntu/Debian
sudo apt install nvidia-cuda-toolkit

# Or download from NVIDIA:
# https://developer.nvidia.com/cuda-downloads
```

### Step 2: Convert Model to ONNX

```bash
pip install tf2onnx tensorflow onnx
python tools/convert_tflite_to_onnx.py mobilenet_v2.tflite mobilenet_v2.onnx
```

### Step 3: Use CUDA Provider

Select "CUDA" as the device in the benchmark app.

## Model Conversion Notes

### TFLite → ONNX Conversion

```bash
# Basic conversion
python -m tf2onnx.convert --tflite model.tflite --output model.onnx --opset 13

# With optimization
python -m tf2onnx.convert --tflite model.tflite --output model.onnx --opset 13 --fold_const
```

### Supported Models

Most classification and feature extraction models convert well:
- MobileNet V1/V2/V3
- EfficientNet
- ResNet
- Custom embedding models

### Potential Issues

1. **Dynamic shapes**: Some TFLite models use dynamic batch sizes. ONNX Runtime handles this automatically.

2. **Custom ops**: If your model uses custom TFLite ops, they may not convert to ONNX.

3. **Quantized models**: INT8 quantized models may need special handling:
   ```bash
   python -m tf2onnx.convert --tflite model_quant.tflite --output model.onnx --opset 13
   ```

## Performance Comparison

Typical speedups with GPU:

| Device | CPU Time | GPU Time | Speedup |
|--------|----------|----------|---------|
| Pixel 7 Pro | 15ms | 5ms | 3x |
| iPhone 14 | 12ms | 4ms | 3x |
| RTX 3080 (CUDA) | 8ms | 1ms | 8x |
| RX 6800 (DirectML) | 10ms | 2ms | 5x |

## Troubleshooting

### "DirectML provider not found"

Ensure you're using a GPU-enabled build of ONNX Runtime:
```yaml
# pubspec.yaml
onnxruntime: ^1.4.1
```

### "CUDA provider not found"

1. Check CUDA is installed: `nvcc --version`
2. Check GPU is detected: `nvidia-smi`
3. Ensure CUDA version matches ONNX Runtime requirements

### "Model inference is slow"

1. First inference is slow due to JIT compilation
2. Run warmup iterations before benchmarking
3. Check that GPU provider is actually being used (see debug logs)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AI Benchmark App                      │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────┐    ┌──────────────────────────┐   │
│  │   TfliteEngine   │    │      OnnxEngine          │   │
│  │   (.tflite)      │    │      (.onnx)             │   │
│  ├──────────────────┤    ├──────────────────────────┤   │
│  │ Android: OpenCL  │    │ Windows: DirectML        │   │
│  │ iOS:     Metal   │    │ Linux:   CUDA            │   │
│  │ macOS:   Metal   │    │ macOS:   CoreML          │   │
│  │ Win/Lin: CPU only│    │ Android: NNAPI           │   │
│  └──────────────────┘    └──────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```
