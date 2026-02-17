# GPU 推論アーキテクチャ

## コンポーネント図

```
┌─────────────────────────────────────────────────────────────────┐
│                         HomeScreen (UI)                          │
│  • エンジン選択 (Histogram, TFLite, ONNX, DirectML, Server)     │
│  • デバイス選択 (CPU, GPU, DirectML, NNAPI, CoreML など)        │
│  • テストセットの読み込み                                        │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ├──────────────────────────────────────────────┐
                  │                                              │
                  ▼                                              ▼
┌─────────────────────────────────┐      ┌────────────────────────────────┐
│   GpuCapabilityChecker          │      │     ModelManager               │
│  (プラットフォーム検出)         │      │   (モデルのダウンロード/パス)  │
│                                 │      │                                │
│  • detectPlatform()             │      │  • getModelPath()              │
│  • availableTfliteDevices       │      │  • downloadModel()             │
│  • availableOnnxDevices         │      │                                │
│  • isDirectMLAvailable          │      └────────────────────────────────┘
│  • isNNAPIAvailable             │
└─────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      InferenceEngine                             │
│                    (抽象インターフェース)                        │
│                                                                  │
│  • initialize()                                                  │
│  • compareImages(path1, path2) -> double                        │
│  • runSyntheticBenchmark() -> PerfStats                         │
│  • dispose()                                                     │
└────┬─────────────┬─────────────┬──────────────┬─────────────────┘
     │             │             │              │
     ▼             ▼             ▼              ▼
┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌───────────────┐
│Histogram │ │ TFLite   │ │ OnnxEngine  │ │OnnxDirectML   │
│Engine    │ │Engine    │ │             │ │Engine         │
└──────────┘ └────┬─────┘ └──────┬──────┘ └───────┬───────┘
                  │              │                 │
                  │              │                 │
                  ▼              ▼                 ▼
         ┌──────────────┐ ┌─────────────┐ ┌──────────────┐
         │GPU Delegate  │ │NNAPI/CoreML │ │DirectML FFI  │
         │ (モバイル)   │ │  Provider   │ │  バインディング│
         └──────────────┘ └─────────────┘ └──────────────┘
```

## データフロー

### エンジン初期化フロー

```
ユーザーがエンジンとデバイスを選択
         │
         ▼
  GpuCapabilityChecker
  利用可能性を確認
         │
         ▼
  エンジンコンストラクタ
  (modelPath, device)
         │
         ▼
   engine.initialize()
         │
         ├──> GPU/アクセラレータを試行
         │    │
         │    ├──> 成功 ────────┐
         │    │                 │
         │    └──> 失敗 ────────┤
         │                      │
         └──> CPU にフォールバック┘
                      │
                      ▼
            actualDevice を記録
                      │
                      ▼
        "Model (Engine-Device)" を表示
```

### 推論フロー

```
ユーザーがベンチマークを実行
         │
         ▼
  テストペアを読み込み
         │
         ▼
各画像ペアについて:
         │
         ├──> 画像1を読み込み ──> 前処理 ──> 埋め込み ──┐
         │                                              │
         └──> 画像2を読み込み ──> 前処理 ──> 埋め込み ──┤
                                                        │
                                                        ▼
                                                コサイン類似度
                                                        │
                                                        ▼
                                              閾値との比較
                                                        │
                                                        ▼
                                              結果を記録 (TP/TN/FP/FN)
                                                        │
                                                        ▼
                                                統計を集計
                                                        │
                                                        ▼
                                          JSON/CSV にエクスポート
```

## プラットフォーム固有の実装

### Windows
```
OnnxDirectMLEngine
       │
       ├──> OnnxDirectMLFFI.initialize()
       │    │
       │    ├──> DirectML DLL の読み込みを試行
       │    │    │
       │    │    ├──> 見つかった ──> DirectML プロバイダーを使用
       │    │    │
       │    │    └──> 見つからない ──> 警告をログ出力
       │    │
       │    └──> XNNPACK にフォールバック
       │
       ├──> プロバイダー付きで OrtSession を作成
       │
       └──> actualDevice = "DirectML" | "XNNPACK" | "CPU"
```

### Android
```
TfliteEngine (device="GPU")
       │
       ├──> GpuDelegateV2 を作成
       │    │
       │    ├──> 成功 ──> InterpreterOptions に追加
       │    │
       │    └──> 失敗 ──> エラーをログ出力、デリゲートを削除
       │
       ├──> オプション付きで Interpreter を作成
       │    │
       │    ├──> 成功 ──> actualDevice = "GPU"
       │    │
       │    └──> 失敗 ──> デリゲートなしで再試行、actualDevice = "CPU"
       │
       └──> 初期化済みエンジンを返す

OnnxEngine (device="NNAPI")
       │
       ├──> OrtSessionOptions を作成
       │
       ├──> appendNnapiProvider()
       │    │
       │    ├──> 成功 ──> actualDevice = "NNAPI"
       │    │
       │    └──> 失敗 ──> appendCPUProvider(), actualDevice = "CPU"
       │
       └──> オプション付きで OrtSession を作成
```

### iOS/macOS
```
TfliteEngine (device="GPU")
       │
       ├──> GpuDelegate (Metal) を作成
       │    │
       │    └──> InterpreterOptions に追加
       │
       └──> actualDevice = "GPU" | "CPU"

OnnxEngine (device="CoreML")
       │
       ├──> OrtSessionOptions を作成
       │
       ├──> appendCoreMLProvider()
       │    │
       │    └──> Apple Neural Engine/GPU を使用
       │
       └──> actualDevice = "CoreML" | "CPU"
```

## リソース管理

### シングルトンパターン (OrtEnv)
```
┌─────────────────────────────────┐
│         OrtEnv.instance         │
│    (シングルトン、アプリ全体)   │
│                                 │
│  • init() - 一度だけ呼び出し   │
│  • release() - 個別のエンジン   │
│         からは呼び出さない      │
└────┬───────────────────┬────────┘
     │                   │
     ▼                   ▼
┌──────────┐      ┌──────────┐
│OnnxEngine│      │DirectML  │
│ Session  │      │Engine    │
│          │      │Session   │
│dispose():│      │          │
│ session  │      │dispose():│
│  .release│      │ session  │
│ opts     │      │  .release│
│  .release│      │ opts     │
│          │      │  .release│
└──────────┘      └──────────┘
```

### エンジンごとのリソース
```
TfliteEngine
       │
       ├──> _interp (Interpreter)
       │    └──> dispose 時に close()
       │
       └──> _gpuDelegate (使用時)
            └──> dispose 時に delete()

OnnxEngine / DirectMLEngine
       │
       ├──> _session (OrtSession)
       │    └──> dispose 時に release()
       │
       ├──> _opts (OrtSessionOptions)
       │    └──> dispose 時に release()
       │
       └──> OrtEnv.instance
            └──> 解放しない (シングルトン)
```

## エラーハンドリング

### GPU 初期化エラー
```
GPU の初期化を試行
       │
       ├──> 成功
       │    └──> actualDevice = 要求されたデバイス
       │
       └──> 失敗
            │
            ├──> 詳細付きでエラーをログ出力
            │
            ├──> CPU にフォールバック
            │    └──> actualDevice = "CPU"
            │
            └──> 実行を継続 (クラッシュなし)
```

### モデル読み込みエラー
```
モデルを読み込み
       │
       ├──> ファイルが存在する
       │    └──> バイトを読み込み
       │
       └──> ファイルが見つからない
            │
            └──> 例外をスローしメッセージを表示:
                 "モデルがダウンロードされていません"
                 UI にエラーを表示
                 モデル管理画面に遷移可能
```

## パフォーマンス監視

```
runSyntheticBenchmark(runs=100)
       │
       ├──> ウォームアップ (30 回)
       │    └──> 結果を破棄
       │
       ├──> ベンチマーク実行
       │    │
       │    └──> 各実行ごとに:
       │         ├──> タイマー開始
       │         ├──> 推論を実行
       │         ├──> タイマー停止
       │         └──> レイテンシを記録
       │
       ├──> レイテンシをソート
       │
       └──> 統計を算出:
            ├──> 平均
            ├──> P50 (中央値)
            ├──> P90
            ├──> 最小
            ├──> 最大
            └──> FPS = 1000 / mean_ms
```

## UI ステート管理

```
HomeScreen State
       │
       ├──> _selectedEngine: String
       │    └──> 作成するエンジンを制御
       │
       ├──> _selectedDevice: String
       │    └──> エンジンコンストラクタに渡される
       │
       ├──> _updateAvailableDevice()
       │    │
       │    └──> エンジン変更時:
       │         ├──> エンジンの利用可能デバイスを取得
       │         └──> 無効な場合 _selectedDevice を更新
       │
       └──> _createEngine()
            │
            └──> _selectedEngine で分岐:
                 ├──> "tflite" ──> TfliteEngine(device: _selectedDevice)
                 ├──> "onnx" ──> OnnxEngine(device: _selectedDevice)
                 ├──> "onnx_directml" ──> DirectMLEngine(device: _selectedDevice)
                 └──> その他
```

## 主要な設計判断

1. **シングルトン OrtEnv**: 複数回の init/release 呼び出しによるクラッシュを防止
2. **フォールバックパターン**: GPU がなくてもアプリが常に動作することを保証
3. **実際のデバイス追跡**: 要求されたものではなく、実際に使用されているデバイスをユーザーに表示
4. **プラットフォーム抽象化**: GpuCapabilityChecker がプラットフォーム検出を一元化
5. **最小限の変更**: 完全な書き直しではなく、既存エンジンの拡張
6. **エラー耐性**: すべての GPU 初期化ポイントで try-catch とフォールバックを実施
