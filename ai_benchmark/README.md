# AI Benchmark Runner

AIモデルによる画像類似度ベンチマークツールです。人間と同じテストセットをAIに解かせ、精度と速度を測定します。

## 機能

- 🤖 **複数のAIモデル**: MobileNet V1/V2/V4、Inception V3、SqueezeNet、DenseNet
- 🚀 **ハードウェアアクセラレーション**: GPU Delegate、NNAPI（Android）、CPU
- 📊 **詳細な結果**: CSV形式で推論時間、類似度スコア、正答率をエクスポート
- 📦 **モデル自動ダウンロード**: アプリ起動時に必要なモデルを自動ダウンロード
- 🎯 **柔軟なテストセット**: ZIPまたはフォルダからテストデータを読み込み

## セットアップ

### 必要条件
- Flutter SDK 3.0以上
- Dart 3.0以上

### インストール

```bash
cd ai_benchmark
flutter pub get
```

### 実行

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows

# Mac
flutter run -d macos

# Linux
flutter run -d linux
```

### ビルド

```bash
# Android (Release APK)
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# Mac
flutter build macos --release

# Linux
flutter build linux --release
```

## 搭載AIモデル

| モデル名 | 特徴 | 入力サイズ | 出典 |
|---|---|---|---|
| **MobileNet V1** | 軽量ベースライン | 224 | [TensorFlow](https://github.com/tensorflow/models) |
| **MobileNet V2** | 標準軽量モデル | 224 | [TensorFlow](https://github.com/tensorflow/models) |
| **MobileNet V4** | 最新モデル（2024） | 224 | [byoussef/HuggingFace](https://huggingface.co/byoussef/MobileNetV4_Conv_Medium_TFLite_224) |
| **Inception V3** | 高精度モデル | 299 | [Google](https://arxiv.org/abs/1512.00567) |
| **SqueezeNet** | 超軽量モデル | 224 | [DeepScale](https://arxiv.org/abs/1602.07360) |
| **DenseNet** | 密結構造ネットワーク | 224 | [Huang et al.](https://arxiv.org/abs/1608.06993) |
| **Color Histogram** | AI不使用（対照実験用） | - | - |

## ハードウェアアクセラレーション

| アクセラレータ | 対応プラットフォーム | 説明 |
|---|---|---|
| **GPU Delegate** | Android, iOS | OpenGL/Metalによる高速推論 |
| **NNAPI** | Android | NPUを使用した省電力推論 |
| **CPU** | 全プラットフォーム | フォールバック（マルチスレッド） |

## ディレクトリ構造

```
ai_benchmark/
├── lib/
│   ├── main.dart                      # エントリポイント
│   ├── engines/
│   │   ├── inference_engine.dart      # 推論エンジン基底クラス
│   │   ├── tflite_engine.dart         # TFLite推論エンジン
│   │   └── histogram_engine.dart      # ヒストグラムエンジン
│   ├── services/
│   │   ├── model_manager.dart         # モデルダウンロード管理
│   │   ├── hardware_checker.dart      # ハードウェア対応チェック
│   │   └── test_set_loader.dart       # テストセット読み込み
│   └── models/
│       └── quiz_question.dart         # 問題データモデル
├── pubspec.yaml                       # 依存関係
└── README.md                          # 本ファイル
```

## 使用ライブラリ

| ライブラリ | 用途 | ライセンス |
|---|---|---|
| [tflite_flutter](https://pub.dev/packages/tflite_flutter) | TensorFlow Lite推論 | Apache 2.0 |
| [image](https://pub.dev/packages/image) | 画像処理 | BSD |
| [path_provider](https://pub.dev/packages/path_provider) | ローカルストレージパス取得 | BSD |
| [csv](https://pub.dev/packages/csv) | CSVエクスポート | BSD |
| [permission_handler](https://pub.dev/packages/permission_handler) | 権限管理 | MIT |
| [archive](https://pub.dev/packages/archive) | ZIP解凍 | Apache 2.0 |

## 使い方

1. **初回起動**: モデルが自動ダウンロードされます
2. **エンジン選択**: 使用するAIモデルを選択
3. **デバイス選択**: CPU/GPU/NNAPIから選択
4. **テストセット読み込み**: ZIPファイルまたはフォルダを選択
5. **ベンチマーク開始**: STARTボタンで計測開始
6. **結果確認**: 自動的にCSVファイルがエクスポートされます

## テストセット形式

### ZIP形式
```
testset.zip
├── category/
│   ├── 001/
│   │   ├── image_a.jpg
│   │   ├── image_b.jpg
│   │   └── metadata.json  {"is_same": true/false}
│   ├── 002/
│   │   ├── image_a.jpg
│   │   ├── image_b.jpg
│   │   └── metadata.json
│   └── ...
```

### CSV結果形式
```csv
Question ID,Genre,Actual Match,Predicted Match,Correct,Similarity Score,Time (ms),Model,Device
1,Cat,True,True,Yes,0.9234,45,MobileNet V2,GPU
2,Cat,False,True,No,0.8654,38,MobileNet V2,GPU
...
```

## 技術スタック

- **言語**: Dart 3.0+
- **フレームワーク**: Flutter 3.0+
- **AIフレームワーク**: TensorFlow Lite
- **アーキテクチャ**: Clean Architecture + Repository Pattern

---

*このアプリは日本の高等学校における総合探究の研究プロジェクトとして開発されました。*
