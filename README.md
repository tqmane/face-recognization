# 🎯 判別クイズ - Similarity Quiz

<div align="center">

**AIと人間、どちらが「似ているもの」を見分けられるか？**

*日本の高等学校における総合探究の研究プロジェクト*

[![Android Build](https://github.com/tqmane/face-recognization/actions/workflows/android-build.yml/badge.svg)](https://github.com/tqmane/face-recognization/actions/workflows/android-build.yml)
[![Flutter Build](https://github.com/tqmane/face-recognization/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/tqmane/face-recognization/actions/workflows/flutter-build.yml)

</div>

## 📖 概要

このプロジェクトは、**AIと人間の画像判別能力を比較する研究**のために開発されたクイズアプリです。

双子、そっくりさん、似ている動物（チーターとヒョウなど）、似ている車種など、
非常に似たものの画像を表示し、「同じもの」か「違うもの」かを判断させます。

### 研究目的

- AIと人間、どちらがより正確に「似ているもの」を判別できるか
- 判別にかかる時間の比較
- ジャンル（動物、人物、車など）による正答率の違い

## 🚀 プロジェクト構成

```
similarity-quiz/
├── android-app/          # Android版アプリ（Kotlin）
│   └── README.md         # Androidアプリの詳細説明
│
├── flutter-app/          # Flutter版アプリ（デスクトップ向け）
│   └── README.md         # Flutterアプリの詳細説明
│
├── tools/                # Python画像収集ツール
│   └── README.md         # ツールの使い方
│
└── .github/workflows/    # GitHub Actions（自動ビルド）
```

### 各アプリの用途

| アプリ | プラットフォーム | 主な用途 |
|--------|------------------|----------|
| Android版 | スマートフォン・タブレット | モバイルでのクイズ・テスト |
| Flutter版 | Windows / Mac / Linux | デスクトップでの研究用テスト |

## 📱 機能

### 共通機能

- 🎮 **オンラインモード**: リアルタイムで画像を取得してクイズ
- 📁 **テストセットモード**: 事前ダウンロードでオフラインテスト
- 📊 **詳細な結果表示**: 正答率、回答時間、問題別結果
- 🌙 **ダークモード対応**

### ジャンル（17種類）

| カテゴリ | ジャンル |
|----------|----------|
| 🐱 ネコ科 | 大型（ライオン、チーター等）、小型（猫種） |
| 🐕 イヌ科 | 犬種、野生（オオカミ、キツネ等） |
| 🦝 その他哺乳類 | アライグマ系、クマ科、霊長類 |
| 🦅 その他動物 | 鳥類、海洋動物、爬虫類、昆虫 |
| 👥 人物 | 双子、そっくりさん |
| 🚗 その他 | 車、ロゴ |

## 🔧 クイックスタート

### Android版

```bash
cd android-app
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

または [GitHub Actions](../../actions) からビルド済みAPKをダウンロード

### Flutter版（デスクトップ）

```bash
cd flutter-app
flutter pub get
flutter run -d windows  # または macos, linux
```

## 🌐 使用している外部サービス・API

このアプリは以下の外部サービスを使用して画像を取得しています。
すべて無料のAPIを教育目的で使用しています。

### 画像ソース

| サービス | 用途 | ライセンス |
|----------|------|------------|
| [iNaturalist](https://www.inaturalist.org/) | 野生動物の研究グレード写真 | CC BY-NC |
| [GBIF](https://www.gbif.org/) | 自然史博物館等の生物多様性データ | 各データ提供者による |
| [The Dog API](https://thedogapi.com/) | 犬種ごとの写真 | 無料利用可 |
| [The Cat API](https://thecatapi.com/) | 猫種ごとの写真 | 無料利用可 |
| [Unsplash](https://unsplash.com/) | 高品質な写真（車等） | Unsplash License |
| [Wikimedia Commons](https://commons.wikimedia.org/) | ロゴ等 | 各ファイルによる |
| [Bing Images](https://www.bing.com/images) | フォールバック | - |

### 謝辞

- **iNaturalist** - 市民科学プロジェクトとして、世界中の研究者・愛好家が提供する高品質な野生動物写真
- **GBIF (Global Biodiversity Information Facility)** - 世界中の自然史博物館・研究機関からの生物多様性データ
- **The Dog API / The Cat API** - 犬種・猫種の正確な写真データベース

## 📊 研究での使い方

### 1. テストセットの作成
事前に画像をダウンロードして、同じ条件でテストを実施できます。

### 2. テストの実施
- 問題数を選択（5〜50問）
- クイズに回答
- 回答時間を自動計測

### 3. 結果の分析
Flutter版ではCSVエクスポート機能で以下のデータを取得できます：
- 問題ごとの正誤
- 回答時間（ミリ秒）
- ジャンル別の正答率

## 🛠 技術スタック

### Android版
- **言語**: Kotlin
- **UI**: Material Design 3
- **非同期処理**: Kotlin Coroutines
- **ネットワーク**: OkHttp, Jsoup

### Flutter版
- **言語**: Dart 3.0+
- **フレームワーク**: Flutter 3.0+
- **プラットフォーム**: Windows, macOS, Linux

## 📄 ライセンス

このプロジェクトは**教育目的**で開発されています。
研究・教育目的での使用を歓迎します。

---

<div align="center">

**🏫 日本の高等学校 総合探究プロジェクト**

*2024-2025年度*

</div>
