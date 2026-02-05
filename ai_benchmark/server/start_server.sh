#!/bin/bash
# Linux用 GPU推論サーバー起動スクリプト
#
# 使用方法:
#   ./start_server.sh
#   ./start_server.sh --model /path/to/model.onnx
#

echo "============================================================"
echo "AI Benchmark GPU推論サーバー (Linux)"
echo "============================================================"

# スクリプトのディレクトリに移動
cd "$(dirname "$0")"

# Pythonの確認
if ! command -v python3 &> /dev/null; then
    echo "[エラー] Python3が見つかりません"
    echo "Python 3.8以上をインストールしてください"
    exit 1
fi

# 仮想環境の作成 (初回のみ)
if [ ! -d "venv" ]; then
    echo "[情報] 仮想環境を作成中..."
    python3 -m venv venv
fi

# 仮想環境の有効化
source venv/bin/activate

# 依存関係の確認
if ! python3 -c "import fastapi" &> /dev/null; then
    echo "[情報] 依存関係をインストール中..."
    pip install -r requirements.txt
fi

# ONNX Runtime GPUの確認
HAS_CUDA=$(python3 -c "import onnxruntime; print('CUDAExecutionProvider' in onnxruntime.get_available_providers())" 2>/dev/null)

if [ "$HAS_CUDA" != "True" ]; then
    echo "[情報] CUDA版ONNX Runtimeをインストール中..."
    echo "  注意: NVIDIA GPUとCUDAがインストールされている必要があります"
    pip install onnxruntime-gpu
fi

echo ""
echo "サーバーを起動しています..."
echo "停止するには Ctrl+C を押してください"
echo ""

python3 inference_server.py "$@"
