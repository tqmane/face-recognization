# Windows/Linux GPU推論ガイド

このガイドでは、Windows/Linux環境でGPUアクセラレーションを有効にする方法を説明します。

## 概要

Flutterの`onnxruntime`パッケージはDirectML/CUDAを直接サポートしていないため、
ローカルPythonサーバー経由でGPU推論を行います。

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  AI Benchmark アプリ                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              GpuServerEngine (Flutter)                │  │
│  │                    ↓ HTTP                             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               GPU推論サーバー (Python)                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ONNX Runtime + GPU Provider              │  │
│  │  ├─ Windows: DirectML (AMD/Intel/NVIDIA対応)         │  │
│  │  └─ Linux:   CUDA (NVIDIA) / ROCm (AMD)              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 対応GPU

| プラットフォーム | GPUプロバイダー | 対応GPU |
|-----------------|----------------|---------|
| **Windows** | DirectML | AMD, Intel, NVIDIA (全メーカー) |
| **Linux** | CUDA | NVIDIA |
| **Linux** | ROCm | AMD (要設定) |

## セットアップ手順

### 前提条件

- **Python 3.8以上** がインストールされていること
- **GPU** が搭載されたPC
- (Linux CUDA) NVIDIA CUDAドライバーがインストールされていること

### ステップ 1: ONNXモデルの準備

TFLiteモデルをONNX形式に変換する必要があります。

```bash
# 変換ツールのインストール
pip install tf2onnx tensorflow

# TFLite → ONNX 変換
python -m tf2onnx.convert \
  --tflite mobilenet_v3_small_embedder.tflite \
  --output mobilenet_v3_small_embedder.onnx \
  --opset 13
```

または、GitHub Actionsで自動変換されたモデルを使用できます:
- Releasesページから `.onnx` ファイルをダウンロード

### ステップ 2: サーバーの起動

#### Windows

```powershell
cd ai_benchmark\server

# 初回: 依存関係のインストール
pip install -r requirements.txt
pip install onnxruntime-directml  # DirectML版

# サーバー起動
python inference_server.py

# または起動スクリプトを使用
.\start_server.bat
```

#### Linux

```bash
cd ai_benchmark/server

# 初回: 依存関係のインストール
pip install -r requirements.txt
pip install onnxruntime-gpu  # CUDA版

# サーバー起動
python inference_server.py

# または起動スクリプトを使用
./start_server.sh
```

### ステップ 3: モデルの読み込み

サーバー起動時にモデルを指定:
```bash
python inference_server.py --model /path/to/model.onnx
```

または、APIで動的に読み込み:
```bash
curl -X POST "http://127.0.0.1:8765/load?model_path=/path/to/model.onnx"
```

## API リファレンス

### ヘルスチェック

```bash
curl http://127.0.0.1:8765/health
```

レスポンス:
```json
{
  "status": "ok",
  "gpu_available": true
}
```

### 利用可能なプロバイダー

```bash
curl http://127.0.0.1:8765/providers
```

レスポンス:
```json
{
  "available": [
    {"name": "DmlExecutionProvider", "description": "DirectML (Windows)"},
    {"name": "CPUExecutionProvider", "description": "CPU"}
  ],
  "recommended": "DmlExecutionProvider",
  "current": "DmlExecutionProvider"
}
```

### モデル読み込み

```bash
curl -X POST "http://127.0.0.1:8765/load?model_path=C:/models/model.onnx&input_size=224"
```

### 画像比較

```bash
curl -X POST http://127.0.0.1:8765/compare \
  -H "Content-Type: application/json" \
  -d '{"image_path1": "/path/to/image1.jpg", "image_path2": "/path/to/image2.jpg"}'
```

レスポンス:
```json
{
  "success": true,
  "similarity": 0.8542
}
```

### ベンチマーク

```bash
curl -X POST http://127.0.0.1:8765/benchmark \
  -H "Content-Type: application/json" \
  -d '{"warmup_runs": 30, "runs": 200}'
```

レスポンス:
```json
{
  "success": true,
  "runs": 200,
  "provider": "DmlExecutionProvider",
  "mean_ms": 2.345,
  "p50_ms": 2.201,
  "p90_ms": 2.892,
  "fps": 426.4
}
```

## アプリでの使用方法

1. サーバーを起動
2. アプリの「性能チェック」画面で「GPU Server」を選択
3. ベンチマークを実行

```dart
// コード例
final engine = GpuServerEngine(
  modelName: 'MobileNet V3',
  modelPath: '/path/to/model.onnx',
  inputSize: 224,
);

await engine.initialize();
final similarity = await engine.compareImages(image1, image2);
final stats = await engine.runSyntheticBenchmark();
engine.dispose();
```

## トラブルシューティング

### 「DirectMLが見つからない」

```bash
# DirectML版を再インストール
pip uninstall onnxruntime onnxruntime-directml -y
pip install onnxruntime-directml
```

### 「CUDAが見つからない」

1. NVIDIAドライバーを確認: `nvidia-smi`
2. CUDAバージョンを確認
3. 対応バージョンのonnxruntime-gpuをインストール:
   ```bash
   pip install onnxruntime-gpu==1.16.0
   ```

### 「サーバーに接続できない」

1. サーバーが起動しているか確認
2. ファイアウォールでポート8765が許可されているか確認
3. `http://127.0.0.1:8765/health` にアクセスできるか確認

### パフォーマンスが遅い

1. 初回推論は遅い（JITコンパイル）- ウォームアップ後に再測定
2. GPUプロバイダーが使用されているか確認: `/providers` API
3. 電源設定を「高パフォーマンス」に変更

## 期待されるパフォーマンス

| GPU | モデル | 推論時間 |
|-----|-------|---------|
| RTX 3080 | MobileNet V3 Small | ~1-2ms |
| RTX 3060 | MobileNet V3 Small | ~2-3ms |
| RX 6800 | MobileNet V3 Small | ~2-4ms (DirectML) |
| Intel UHD 630 | MobileNet V3 Small | ~5-10ms (DirectML) |
| CPU (8コア) | MobileNet V3 Small | ~10-20ms |

GPU使用時は **5-10倍の高速化** が期待できます。
