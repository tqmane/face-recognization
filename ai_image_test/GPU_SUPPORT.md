# Windows および Android 向け GPU 推論サポート

## 概要

この実装は、Windows（DirectML 経由）の GPU アクセラレーションサポートを追加し、ai_image_test プロジェクトにおける Android の GPU サポートを強化するものです。

## 変更内容

### 1. 依存関係の追加 (pubspec.yaml)
- ネイティブ DirectML ライブラリとの連携のため、FFI サポートとして `ffi: ^2.1.3` を追加

### 2. 新しいサービス

#### GpuCapabilityChecker (`lib/services/gpu_capability_checker.dart`)
異なるプラットフォーム間で GPU 機能を検出するシングルトンサービス：
- **TFLite GPU**: Android、iOS、macOS で利用可能
- **DirectML**: Windows で利用可能（NVIDIA、AMD、Intel GPU）
- **NNAPI**: Android で利用可能
- **CoreML**: iOS および macOS で利用可能
- プラットフォーム固有のデバイスリストを提供
- デバッグ用に機能をログ出力

#### OnnxDirectMLFFI (`lib/services/onnx_directml_ffi.dart`)
Windows 上の DirectML サポート付き ONNX Runtime の FFI バインディング。

### 3. 新しいエンジン

#### OnnxDirectMLEngine (`lib/engines/onnx_directml_engine.dart`)
Windows 向け DirectML サポート付き ONNX Runtime エンジン：
- DirectML を使用して Windows 上で GPU アクセラレーションを提供
- NVIDIA、AMD、Intel GPU をサポート
- DirectML が利用できない場合は XNNPACK/CPU にフォールバック
- 実際に使用されたデバイスを追跡（`_actualDevice`）
- 適切なリソース管理（シングルトン OrtEnv を解放しない）

### 4. 既存エンジンの強化

#### TfliteEngine (`lib/engines/tflite_engine.dart`)
- プラットフォーム検出に `GpuCapabilityChecker` を使用するように変更
- `actualDevice` プロパティで実際に使用されたデバイスを返却

#### OnnxEngine (`lib/engines/onnx_engine.dart`)
- デバイスの可用性確認のため `GpuCapabilityChecker` を統合
- 実際に使用されているデバイスを表示するための `_actualDevice` 追跡を追加
- CPU への自動フォールバックによるエラーハンドリングの改善
- リソース管理の修正（dispose 時にシングルトン OrtEnv を解放しない）
- 初期化失敗時のログ出力を改善

### 5. UI の更新

#### HomeScreen (`lib/screens/home_screen.dart`)
- Windows 向け ONNX DirectML エンジンオプションを追加
- TFLite および ONNX エンジン向けのデバイス選択ドロップダウン
- 現在のプラットフォームで利用可能な GPU 機能を表示
- エンジンタイプ変更時にデバイスリストを自動更新
- 選択されたデバイスをエンジンコンストラクタに渡す

## プラットフォーム固有のサポート

### Windows
- **ONNX DirectML**: DirectML による GPU アクセラレーション（onnxruntime パッケージの制限により、現在は XNNPACK をフォールバックとして使用）
- **TFLite**: CPU のみ（Windows では GPU デリゲートなし）
- **推奨**: 最高のパフォーマンスを得るには ONNX DirectML エンジンを使用

### Android
- **TFLite GPU**: モバイル GPU 向け GPU Delegate V2
- **ONNX NNAPI**: ハードウェアアクセラレーション向け Neural Networks API
- **ONNX XNNPACK**: 最適化された CPU 推論
- **推奨**: 最高のパフォーマンスを得るには TFLite GPU または ONNX NNAPI を使用

### iOS/macOS
- **TFLite GPU**: Apple GPU 向け GPU Delegate
- **ONNX CoreML**: Apple の CoreML フレームワーク
- **推奨**: 最高のパフォーマンスを得るには ONNX CoreML を使用

## 使い方

1. **エンジンタイプの選択**: Histogram、TFLite、ONNX Runtime、ONNX DirectML、または GPU Server から選択
2. **デバイスの選択**: TFLite/ONNX エンジンの場合、利用可能なデバイス（CPU、GPU、DirectML、NNAPI、CoreML、XNNPACK）から選択
3. **ベンチマークの実行**: 選択されたデバイスが推論に使用されます

## フォールバック動作

すべてのエンジンは自動フォールバックを実装しています：
1. 要求された GPU デバイスで初期化を試行
2. GPU の初期化に失敗した場合、エラーをログに記録し CPU で再試行
3. 実際に使用されたデバイスを追跡し、UI に表示（`engine.name`）

## リソース管理

リソース管理の問題を修正：
- **OrtEnv**: インスタンスごとに解放しないように変更（シングルトンのため）
- **Sessions/Options**: エンジン破棄時に適切に解放
- **GPU Delegates**: 失敗時または破棄時に適切に解放

## DirectML に関する注意事項

現在の Dart `onnxruntime` パッケージ（v1.4.1）は DirectML 実行プロバイダーを直接公開していません。この実装では：
1. FFI を介して DirectML DLL の利用可能性を確認
2. 最適化された代替手段として XNNPACK にフォールバック
3. デバッグ用に DirectML リクエストをログに記録

完全な DirectML サポートには以下が必要です：
- システム PATH に ONNX Runtime DirectML DLL を配置
- ONNX Runtime C API へのカスタム FFI バインディング
- または DirectML サポートが追加された場合、新しい onnxruntime パッケージに更新

## テスト

実装をテストするには：
1. Windows で実行し、ログで DirectML の利用可能性を確認
2. Android で実行し、TFLite GPU と ONNX NNAPI をテスト
3. GPU のないデバイスでテストしてフォールバック動作を検証
4. 合成ベンチマークでパフォーマンスの改善を確認

## 今後の改善予定

1. Windows 向けの完全な DirectML FFI 実装
2. より詳細な GPU 機能検出の追加（ベンダー、メモリなど）
3. モデルごとのデバイス選択を可能にする
4. デバイス間のベンチマーク比較を追加
5. デバイスのウォームアップとパフォーマンスプロファイリングの実装
