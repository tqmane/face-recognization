# GPU Acceleration Guide for AI Benchmark

This guide explains how GPU acceleration works on different platforms.

## Summary

| Platform | Runtime | GPU Provider | In-App GPU | Setup Required |
|----------|---------|--------------|------------|----------------|
| **Android** | TFLite | OpenCL/OpenGL (GpuDelegateV2) | Yes | None (automatic) |
| **iOS** | TFLite | Metal (GpuDelegate) | Yes | None (automatic) |
| **macOS** | TFLite + ONNX | Metal / CoreML | Yes | None (automatic) |
| **Windows** | ONNX Runtime | XNNPACK (CPU最適化) | CPU only | None |
| **Windows** | GPU Server | DirectML | Yes (サーバー経由) | Python + サーバー起動 |
| **Linux** | ONNX Runtime | XNNPACK (CPU最適化) | CPU only | None |
| **Linux** | GPU Server | CUDA | Yes (サーバー経由) | Python + CUDA + サーバー起動 |

## GPU support per platform

### Android (TFLite — GpuDelegateV2)

GPU acceleration works out of the box using TFLite `GpuDelegateV2` with
`isPrecisionLossAllowed: true` (FP16). This maximises compatibility across
devices and models.

- Select **GPU** in the device dropdown.
- If the GPU delegate fails for a specific model, the app automatically falls
  back to **CPU** and shows a notice.
- **量子化モデル (uint8)** は一部のGPUデリゲートと互換性がありません。
  FP32 モデル（推奨: Image Embedder / EfficientNet FP32）を使用してください。

### iOS (TFLite — Metal)

Uses `GpuDelegate` (Apple Metal). Select **GPU** in the device dropdown.

### macOS (TFLite Metal + ONNX CoreML)

- **TFLite models**: Metal via `GpuDelegate` — select **GPU**.
- **ONNX models**: Apple CoreML — select **CoreML**.

### Windows

The Flutter `onnxruntime` package does **not** include DirectML or CUDA
providers. In-app GPU acceleration is not available.

**Available in-app options:**
- **CPU** — default
- **XNNPACK** — optimised CPU execution (recommended)
- **GPU Server** — full GPU acceleration via local Python server (see below)

### Linux

Same as Windows — the Flutter ONNX binding has no CUDA provider.

**Available in-app options:**
- **CPU** — default
- **XNNPACK** — optimised CPU execution (recommended)
- **GPU Server** — full GPU acceleration via local Python server (see below)

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

### Android: GPU テストでクラッシュする

1. **量子化モデル**: MobileNet V1/V2 (uint8 quantized) は一部のGPUで非対応です。
   FP32 モデル（Image Embedder, EfficientNet FP32）を使用してください。
2. アプリは自動的にCPUへフォールバックしますが、ネイティブクラッシュが発生する
   場合は FP32 モデルに切り替えてください。
3. `isPrecisionLossAllowed: true` により FP16 で動作し、互換性が向上しています。

### iOS/macOS: Metal GPU が遅い

1. 初回推論はJITコンパイルのため遅くなります。
2. ウォームアップ後の値を参考にしてください。

### Windows/Linux: ネイティブGPUが使えない

Flutter の `onnxruntime` パッケージは DirectML / CUDA プロバイダーを含んでいません。
GPU推論には **GPU Server モード** を使用してください。

```bash
cd ai_benchmark/server
pip install -r requirements.txt
python inference_server.py
```

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
│  │ Android: OpenCL  │    │ macOS/iOS:  CoreML       │   │
│  │ iOS:     Metal   │    │ Android:    XNNPACK      │   │
│  │ macOS:   Metal   │    │ Win/Linux:  XNNPACK(CPU) │   │
│  │ Win/Lin: CPU only│    │                          │   │
│  └──────────────────┘    └──────────────────────────┘   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │            GpuServerEngine (HTTP)                │   │
│  │  Win: DirectML  /  Linux: CUDA  /  Fallback: CPU │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```
