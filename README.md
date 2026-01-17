# 🎯 判別クイズ - Similarity Quiz Project

<div align="center">

**AIと人間、どちらが「似ているもの」を見分けられるか？**

*日本の高等学校における総合探究の研究プロジェクト*

[![Android Build](https://github.com/tqmane/face-recognization/actions/workflows/android-build.yml/badge.svg)](https://github.com/tqmane/face-recognization/actions/workflows/android-build.yml)
[![Flutter Build](https://github.com/tqmane/face-recognization/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/tqmane/face-recognization/actions/workflows/flutter-build.yml)

</div>

## 📖 概要

このプロジェクトは、**AIと人間の画像判別能力を比較する研究**のために開発されたアプリケーション群です。

双子、そっくりさん、似ている動物（チーターとヒョウなど）、似ている車種など、非常に似たものの画像を表示し、「同じもの」か「違うもの」かを判断させます。

### 研究目的

- **精度比較**: 人間とAI（Deep Learning）の正答率の比較
- **速度比較**: 人間の反応速度と、デバイス（CPU/GPU/NPU）上でのAI推論速度の比較
- **特性分析**: ジャンル（生物、人工物）による得意・不得意の傾向分析

## 🚀 プロジェクト構成

| ディレクトリ | アプリ名 | 用途 | 対象プラットフォーム |
|:---|:---|:---|:---|
| `android-app/` | **人間用クイズアプリ** | 被験者（人間）によるデータ収集 | Android (スマホ/タブレット) |
| `flutter-app/` | **人間用テストアプリ** | デスクトップでの精密なテスト実施 | Windows / Mac / Linux |
| `ai_benchmark/` | **AIベンチマーク** | **AIモデルによる自動テスト・速度計測** | Android / iOS / Desktop |
| `tools/` | 画像収集ツール | 研究用データセットの作成 | Python (CLI) |

## 🤖 AI ベンチマーク機能

新しく実装された **AI Benchmark Runner** (`ai_benchmark/`) は、人間と同じテストセットをAIに解かせるためのツールです。

### 搭載AIモデル (推論エンジン)
以下のモデルを使用して、画像の特徴量を比較・判別します。

| モデル名 | 特徴 | 出典/ライセンス |
|---|---|---|
| **MobileNet V2** | 軽量かつ高精度な標準モデル | [Google / TensorFlow Hub](https://tfhub.dev/google/tf2-preview/mobilenet_v2/classification/4) (Apache 2.0) |
| **MobileNet V1** | 初期の軽量モデル（ベースライン） | [Google](https://github.com/tensorflow/models) (Apache 2.0) |
| **Inception V3** | 高解像度・高精度モデル | [Google](https://arxiv.org/abs/1512.00567) (Apache 2.0) |
| **SqueezeNet** | 超軽量・高速モデル | [DeepScale](https://arxiv.org/abs/1602.07360) (BSD) |
| **Color Histogram** | AIを使用しない色分布比較（対照実験用） | - |

### ハードウェアアクセラレーション
デバイスの性能を最大限に引き出すため、以下のアクセラレータに対応しています。
- **GPU Delegate**: モバイルGPUを使用した高速推論
- **NNAPI (Android)**: NPU (Neural Processing Unit) を使用した省電力・高速推論
- **CPU**: フォールバック用（マルチスレッド対応）

## 🌐 使用データ・クレジット

本研究では、以下のオープンデータおよびAPIを使用しています。
これらは教育・研究目的で利用されています。

### 画像データソース
| サービス | 提供内容 | ライセンス/権利 |
|---|---|---|
| **iNaturalist** | 野生動物の研究グレード写真 | [CC BY-NC](https://creativecommons.org/licenses/by-nc/4.0/) 等 |
| **GBIF** | 生物多様性データ | 各データ提供者に準拠 |
| **The Dog API** | 犬種データセット | 無料利用枠 |
| **The Cat API** | 猫種データセット | 無料利用枠 |
| **Unsplash** | 高品質な一般写真 | [Unsplash License](https://unsplash.com/license) |
| **Wikimedia Commons** | パブリックドメイン画像 | PD, CC BY-SA 等 |

### 使用ライブラリ・技術
- **Flutter & Dart**: Google (BSD 3-Clause)
- **TensorFlow Lite**: Google (Apache 2.0)
- **Android Jetpack**: Google (Apache 2.0)
- **OkHttp**: Square, Inc. (Apache 2.0)
- **Jsoup**: Jonathan Hedley (MIT License)

## 🔧 実行方法

### 1. AIベンチマークの実行
```bash
cd ai_benchmark
flutter pub get
flutter run --release
```
1. アプリを起動し、エンジン（モデル）とデバイス（CPU/GPU）を選択
2. テストセット（ZIPまたはフォルダ）をロード
3. `START` で計測開始

### 2. 人間用アプリ（Android）
```bash
cd android-app
./gradlew assembleDebug
```
生成されたAPKをインストールして使用。

## 📄 ライセンスと免責

このプロジェクトは日本の高等学校における教育活動の一環として作成されました。
ソースコードは **MIT License** の下で公開されていますが、含まれるモデルファイルや収集された画像データについては、それぞれの権利者のライセンスに従ってください。

---
<div align="center">
Created by tqmane for High School Inquiry Project (2024-2026)
</div>