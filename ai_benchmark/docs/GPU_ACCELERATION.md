# GPU Acceleration Guide for AI Benchmark

This guide explains how GPU acceleration works on different platforms.

## Summary

| Platform | Runtime | GPU Provider | Setup Required |
|----------|---------|--------------|----------------|
| **Android** | TFLite | OpenCL/OpenGL | None (automatic) |
| **iOS** | TFLite | Metal | None (automatic) |
| **macOS** | TFLite | Metal | None (automatic) |
| **Windows** | ONNX Runtime | DirectML | None (automatic) |
| **Linux** | ONNX Runtime | CUDA | CUDA Toolkit |

## ✨ Automatic GPU Support

**GPU acceleration now works out of the box!**

When you download a model in the app, it automatically selects the optimal format for your platform:

- **Android/iOS/macOS**: Downloads `.tflite` format (Metal/OpenCL acceleration)
- **Windows**: Downloads `.onnx` format (DirectML - works with AMD, Intel, NVIDIA)
- **Linux**: Downloads `.onnx` format (CUDA for NVIDIA GPUs)

Pre-converted ONNX models are hosted on GitHub Releases and downloaded on demand.

## Mobile Platforms (Android/iOS/macOS)

GPU acceleration works out of the box using TensorFlow Lite.

- **Android**: Uses `GpuDelegateV2` (OpenCL/OpenGL ES)
- **iOS**: Uses `GpuDelegate` (Metal)
- **macOS**: Uses `GpuDelegate` (Metal)

Just select "GPU" in the device dropdown.

## Windows (DirectML)

Windows uses ONNX Runtime with DirectML, which supports **all GPU vendors** (AMD, Intel, NVIDIA).

### Automatic Setup

1. Download any model in the app
2. Select "DirectML" as the device
3. Done! No manual conversion needed.

### Manual Setup (for custom models)

```bash
# Install conversion tools
pip install tf2onnx tensorflow onnx

# Convert model
python tools/convert_tflite_to_onnx.py your_model.tflite your_model.onnx
```

## Linux (CUDA)

Linux uses ONNX Runtime with CUDA for NVIDIA GPUs.

### Prerequisites

- **NVIDIA GPU** with CUDA support
- **CUDA Toolkit** 11.x or 12.x (required for GPU acceleration)

### Install CUDA

```bash
# Ubuntu/Debian
sudo apt install nvidia-cuda-toolkit

# Or download from NVIDIA:
# https://developer.nvidia.com/cuda-downloads
```

### Usage

1. Download any model in the app (ONNX format is selected automatically)
2. Select "CUDA" as the device
3. Done!

**Note**: If CUDA is not installed, the app will fall back to CPU.

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
