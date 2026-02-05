@echo off
REM Windows用 GPU推論サーバー起動スクリプト
REM 
REM 使用方法:
REM   start_server.bat
REM   start_server.bat --model path\to\model.onnx
REM

echo ============================================================
echo AI Benchmark GPU推論サーバー (Windows)
echo ============================================================

REM Pythonの確認
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [エラー] Pythonが見つかりません
    echo Python 3.8以上をインストールしてください
    pause
    exit /b 1
)

REM 依存関係の確認
python -c "import fastapi" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [情報] 依存関係をインストール中...
    pip install -r requirements.txt
)

REM ONNX Runtime DirectMLの確認
python -c "import onnxruntime; print('DmlExecutionProvider' in onnxruntime.get_available_providers())" 2>nul | findstr "True" >nul
if %ERRORLEVEL% NEQ 0 (
    echo [情報] DirectML版ONNX Runtimeをインストール中...
    pip install onnxruntime-directml
)

echo.
echo サーバーを起動しています...
echo 停止するには Ctrl+C を押してください
echo.

python inference_server.py %*
