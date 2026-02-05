#!/usr/bin/env python3
"""
GPU推論サーバー for AI Benchmark

Windows: DirectML (AMD/Intel/NVIDIA対応)
Linux: CUDA (NVIDIA) または ROCm (AMD)

使用方法:
    pip install -r requirements.txt
    python inference_server.py --port 8765
"""

import argparse
import asyncio
import json
import logging
import os
import sys
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image

# FastAPI関連
try:
    from fastapi import FastAPI, HTTPException, UploadFile, File
    from fastapi.responses import JSONResponse
    from pydantic import BaseModel
    import uvicorn
except ImportError:
    print("FastAPIがインストールされていません。以下を実行してください:")
    print("  pip install fastapi uvicorn python-multipart")
    sys.exit(1)

# ONNX Runtime
try:
    import onnxruntime as ort
except ImportError:
    print("ONNX Runtimeがインストールされていません。以下を実行してください:")
    print("  Windows (DirectML): pip install onnxruntime-directml")
    print("  Linux (CUDA):       pip install onnxruntime-gpu")
    print("  CPU fallback:       pip install onnxruntime")
    sys.exit(1)

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AI Benchmark GPU推論サーバー",
    description="Windows/Linux向けGPUアクセラレーション推論API",
    version="1.0.0"
)


class ModelInfo(BaseModel):
    """モデル情報"""
    name: str
    path: str
    input_size: int = 224
    loaded: bool = False
    provider: str = ""


class InferenceRequest(BaseModel):
    """推論リクエスト"""
    image_path: str


class CompareRequest(BaseModel):
    """画像比較リクエスト"""
    image_path1: str
    image_path2: str


class BenchmarkRequest(BaseModel):
    """ベンチマークリクエスト"""
    warmup_runs: int = 30
    runs: int = 200


# グローバル状態
class ServerState:
    def __init__(self):
        self.session: Optional[ort.InferenceSession] = None
        self.model_info: Optional[ModelInfo] = None
        self.provider: str = "CPU"
        self.input_name: str = ""
        self.input_shape: list = []
        self.output_names: list = []

    def get_available_providers(self) -> list:
        """利用可能なプロバイダーを取得"""
        available = ort.get_available_providers()
        logger.info(f"利用可能なプロバイダー: {available}")
        return available

    def get_best_provider(self) -> str:
        """最適なプロバイダーを選択"""
        available = self.get_available_providers()
        
        # 優先順位: DirectML > CUDA > TensorRT > CPU
        priority = [
            'DmlExecutionProvider',      # Windows DirectML
            'CUDAExecutionProvider',     # Linux/Windows CUDA
            'TensorrtExecutionProvider', # TensorRT
            'ROCMExecutionProvider',     # AMD ROCm
            'CPUExecutionProvider',      # Fallback
        ]
        
        for provider in priority:
            if provider in available:
                return provider
        
        return 'CPUExecutionProvider'


state = ServerState()


def preprocess_image(image_path: str, input_size: int = 224) -> np.ndarray:
    """画像を前処理してモデル入力形式に変換"""
    try:
        img = Image.open(image_path).convert('RGB')
        img = img.resize((input_size, input_size), Image.Resampling.LANCZOS)
        
        # Numpy配列に変換 (H, W, C) -> (1, C, H, W)
        arr = np.array(img, dtype=np.float32) / 255.0
        arr = arr.transpose(2, 0, 1)  # HWC -> CHW
        arr = np.expand_dims(arr, axis=0)  # Add batch dimension
        
        return arr
    except Exception as e:
        logger.error(f"画像前処理エラー: {e}")
        raise HTTPException(status_code=400, detail=f"画像読み込みエラー: {e}")


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """コサイン類似度を計算"""
    a = a.flatten()
    b = b.flatten()
    
    dot_product = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    
    if norm_a == 0 or norm_b == 0:
        return 0.0
    
    return float(dot_product / (norm_a * norm_b))


@app.get("/")
async def root():
    """サーバー情報"""
    return {
        "name": "AI Benchmark GPU推論サーバー",
        "version": "1.0.0",
        "provider": state.provider,
        "available_providers": state.get_available_providers(),
        "model_loaded": state.session is not None,
        "model_info": state.model_info.dict() if state.model_info else None
    }


@app.get("/health")
async def health():
    """ヘルスチェック"""
    return {"status": "ok", "gpu_available": state.provider != "CPUExecutionProvider"}


@app.get("/providers")
async def get_providers():
    """利用可能なプロバイダー一覧"""
    available = state.get_available_providers()
    best = state.get_best_provider()
    
    provider_info = []
    for p in available:
        info = {"name": p, "is_gpu": "CPU" not in p}
        if p == "DmlExecutionProvider":
            info["description"] = "DirectML (Windows) - AMD/Intel/NVIDIA対応"
        elif p == "CUDAExecutionProvider":
            info["description"] = "CUDA (NVIDIA GPU)"
        elif p == "ROCMExecutionProvider":
            info["description"] = "ROCm (AMD GPU on Linux)"
        elif p == "TensorrtExecutionProvider":
            info["description"] = "TensorRT (NVIDIA高速化)"
        elif p == "CPUExecutionProvider":
            info["description"] = "CPU (フォールバック)"
        else:
            info["description"] = p
        provider_info.append(info)
    
    return {
        "available": provider_info,
        "recommended": best,
        "current": state.provider
    }


@app.post("/load")
async def load_model(model_path: str, input_size: int = 224, provider: str = "auto"):
    """モデルを読み込む"""
    if not os.path.exists(model_path):
        raise HTTPException(status_code=404, detail=f"モデルが見つかりません: {model_path}")
    
    try:
        # プロバイダー選択
        if provider == "auto":
            selected_provider = state.get_best_provider()
        else:
            available = state.get_available_providers()
            if provider in available:
                selected_provider = provider
            else:
                logger.warning(f"{provider} は利用できません。代替を使用します。")
                selected_provider = state.get_best_provider()
        
        logger.info(f"モデル読み込み中: {model_path} (プロバイダー: {selected_provider})")
        
        # セッションオプション
        sess_options = ort.SessionOptions()
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        
        # セッション作成
        state.session = ort.InferenceSession(
            model_path,
            sess_options,
            providers=[selected_provider]
        )
        
        # 入出力情報取得
        inputs = state.session.get_inputs()
        outputs = state.session.get_outputs()
        
        state.input_name = inputs[0].name
        state.input_shape = inputs[0].shape
        state.output_names = [o.name for o in outputs]
        state.provider = selected_provider
        
        state.model_info = ModelInfo(
            name=Path(model_path).stem,
            path=model_path,
            input_size=input_size,
            loaded=True,
            provider=selected_provider
        )
        
        logger.info(f"モデル読み込み完了: {state.model_info.name}")
        logger.info(f"  入力: {state.input_name} {state.input_shape}")
        logger.info(f"  出力: {state.output_names}")
        
        return {
            "success": True,
            "model": state.model_info.dict(),
            "input_name": state.input_name,
            "input_shape": state.input_shape,
            "output_names": state.output_names
        }
        
    except Exception as e:
        logger.error(f"モデル読み込みエラー: {e}")
        raise HTTPException(status_code=500, detail=f"モデル読み込みエラー: {e}")


@app.post("/unload")
async def unload_model():
    """モデルをアンロード"""
    state.session = None
    state.model_info = None
    state.input_name = ""
    state.input_shape = []
    state.output_names = []
    
    return {"success": True, "message": "モデルをアンロードしました"}


@app.post("/infer")
async def infer(request: InferenceRequest):
    """単一画像の推論"""
    if state.session is None:
        raise HTTPException(status_code=400, detail="モデルが読み込まれていません")
    
    input_size = state.model_info.input_size if state.model_info else 224
    input_data = preprocess_image(request.image_path, input_size)
    
    try:
        outputs = state.session.run(state.output_names, {state.input_name: input_data})
        
        # 出力を正規化
        embedding = outputs[0].flatten().tolist()
        
        return {
            "success": True,
            "embedding": embedding,
            "embedding_size": len(embedding)
        }
    except Exception as e:
        logger.error(f"推論エラー: {e}")
        raise HTTPException(status_code=500, detail=f"推論エラー: {e}")


@app.post("/compare")
async def compare_images(request: CompareRequest):
    """2つの画像を比較"""
    if state.session is None:
        raise HTTPException(status_code=400, detail="モデルが読み込まれていません")
    
    input_size = state.model_info.input_size if state.model_info else 224
    
    try:
        # 両方の画像を推論
        input1 = preprocess_image(request.image_path1, input_size)
        input2 = preprocess_image(request.image_path2, input_size)
        
        output1 = state.session.run(state.output_names, {state.input_name: input1})
        output2 = state.session.run(state.output_names, {state.input_name: input2})
        
        # コサイン類似度計算
        similarity = cosine_similarity(output1[0], output2[0])
        
        return {
            "success": True,
            "similarity": similarity,
            "image1": request.image_path1,
            "image2": request.image_path2
        }
    except Exception as e:
        logger.error(f"比較エラー: {e}")
        raise HTTPException(status_code=500, detail=f"比較エラー: {e}")


@app.post("/benchmark")
async def run_benchmark(request: BenchmarkRequest):
    """ベンチマーク実行"""
    if state.session is None:
        raise HTTPException(status_code=400, detail="モデルが読み込まれていません")
    
    import time
    
    input_size = state.model_info.input_size if state.model_info else 224
    
    # ダミー入力データ
    dummy_input = np.random.rand(1, 3, input_size, input_size).astype(np.float32)
    
    # ウォームアップ
    logger.info(f"ウォームアップ中... ({request.warmup_runs}回)")
    for _ in range(request.warmup_runs):
        state.session.run(state.output_names, {state.input_name: dummy_input})
    
    # ベンチマーク
    logger.info(f"ベンチマーク実行中... ({request.runs}回)")
    times = []
    for _ in range(request.runs):
        start = time.perf_counter()
        state.session.run(state.output_names, {state.input_name: dummy_input})
        end = time.perf_counter()
        times.append((end - start) * 1000)  # ms
    
    times.sort()
    mean_ms = sum(times) / len(times)
    p50_ms = times[int(len(times) * 0.5)]
    p90_ms = times[int(len(times) * 0.9)]
    min_ms = times[0]
    max_ms = times[-1]
    fps = 1000.0 / mean_ms if mean_ms > 0 else 0
    
    result = {
        "success": True,
        "runs": request.runs,
        "provider": state.provider,
        "mean_ms": round(mean_ms, 3),
        "p50_ms": round(p50_ms, 3),
        "p90_ms": round(p90_ms, 3),
        "min_ms": round(min_ms, 3),
        "max_ms": round(max_ms, 3),
        "fps": round(fps, 1)
    }
    
    logger.info(f"ベンチマーク結果: {result}")
    return result


def main():
    parser = argparse.ArgumentParser(description="AI Benchmark GPU推論サーバー")
    parser.add_argument("--host", default="127.0.0.1", help="ホストアドレス")
    parser.add_argument("--port", type=int, default=8765, help="ポート番号")
    parser.add_argument("--model", help="起動時に読み込むモデルパス")
    parser.add_argument("--input-size", type=int, default=224, help="入力サイズ")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("AI Benchmark GPU推論サーバー")
    print("=" * 60)
    print(f"利用可能なプロバイダー: {state.get_available_providers()}")
    print(f"推奨プロバイダー: {state.get_best_provider()}")
    print("=" * 60)
    
    if args.model:
        print(f"モデルを読み込み中: {args.model}")
        # 同期的に読み込み
        import asyncio
        asyncio.run(load_model(args.model, args.input_size))
    
    print(f"サーバー起動: http://{args.host}:{args.port}")
    print("Ctrl+C で停止")
    print("=" * 60)
    
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
