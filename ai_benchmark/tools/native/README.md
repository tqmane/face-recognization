# Desktop向け TensorFlow Lite C ライブラリの作成

`tflite_flutter` はデスクトップ（Linux/Windows/macOS）で `libtensorflowlite_c` を自前で用意する必要があります。
このフォルダのスクリプトは、手元の `tensorflow` ソースから `tensorflow/lite/c` をCMakeでビルドし、アプリが読む場所（`ai_benchmark/blobs/`）にコピーします。

## 前提

- `tensorflow` のソースチェックアウトが必要です（例: `../tensorflow_src`）
- CMake と C/C++ ビルドツールが必要です

### TensorFlowソースの場所

デフォルトでは `../tensorflow_src` を見に行きます。
別の場所にある場合は環境変数で指定してください。

- `TENSORFLOW_SOURCE_DIR=/path/to/tensorflow_src`

重要: **`TF_SOURCE_DIR` と `TENSORFLOW_SOURCE_DIR` を同じローカルツリーに揃える**必要があります。
（揃っていないと、CMakeが別のTensorFlowをダウンロードしてヘッダ/スキーマ不整合で失敗します）

## Linux

```bash
export TENSORFLOW_SOURCE_DIR=../tensorflow_src
export BUILD_DIR=../tflite_build_c_linux
bash ai_benchmark/tools/native/build_tflite_c_linux.sh
```

生成物: `ai_benchmark/blobs/libtensorflowlite_c-linux.so`

## macOS

```bash
export TENSORFLOW_SOURCE_DIR=../tensorflow_src
export BUILD_DIR=../tflite_build_c_macos
bash ai_benchmark/tools/native/build_tflite_c_macos.sh
```

生成物: `ai_benchmark/blobs/libtensorflowlite_c-mac.dylib`

このdylibはビルド時にアプリバンドルへコピーされます。

## Windows (PowerShell)

```powershell
$env:TENSORFLOW_SOURCE_DIR = "..\tensorflow_src"
$env:BUILD_DIR = "..\tflite_build_c_windows"
powershell -ExecutionPolicy Bypass -File ai_benchmark\tools\native\build_tflite_c_windows.ps1
```

生成物: `ai_benchmark\blobs\libtensorflowlite_c-win.dll`

## Android / iOS

Android / iOS は `tflite_flutter` がプラットフォーム向け依存を取得・同梱するため、通常このCライブラリを手動ビルドする必要はありません。
（AndroidはR8/ProGuardのために `tensorflow-lite-gpu-api` を追加済みです）
