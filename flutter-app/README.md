# Flutter判別クイズアプリ

Windows/Mac/Linux/Android/iOS対応のクロスプラットフォームアプリ

## セットアップ

### 必要条件
- Flutter SDK 3.0以上
- Dart 3.0以上

### インストール

```bash
cd flutter-app
flutter pub get
```

### 実行

```bash
# Windows
flutter run -d windows

# Mac
flutter run -d macos

# Linux
flutter run -d linux

# Android
flutter run -d android

# Web (開発用)
flutter run -d chrome
```

### ビルド

```bash
# Windows
flutter build windows

# Mac
flutter build macos

# Linux
flutter build linux

# Android APK
flutter build apk
```

## 機能

- 🎮 オンラインモード: Bingから画像を取得してクイズ
- 📦 テストセット: 事前ダウンロードでオフラインテスト
- 🎯 ジャンル選択: ネコ科、犬種、車、ロゴなど
- ⏱️ タイマー＆スコア表示
- 🌙 ダークモード対応
