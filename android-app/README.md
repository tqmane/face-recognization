# 判別クイズ Android アプリ

似ているものが「同じ」か「違う」かを判断するクイズアプリ

## 機能

- 📷 画像を表示して「同じ/違う」を回答
- ✅ 正解・不正解の即時フィードバック
- 📊 スコア記録
- ⏱️ 時間計測（合計・各問題）
- 🏆 ベストスコア保存
- 📋 詳細な結果表示

## 必要環境

- Android 13 (API 33) 以上

## ビルド方法

### GitHub Actions（推奨）

1. GitHubにプッシュすると自動でビルドされます
2. Actions タブから APK をダウンロード

### ローカルビルド

```bash
cd android-app
./gradlew assembleDebug
```

APKは `app/build/outputs/apk/debug/` に出力されます

## 画像の追加方法

1. `tools/image_downloader.py` で画像を収集
2. `downloaded_images/same/` の画像を `android-app/app/src/main/assets/same/` にコピー
3. `downloaded_images/different/` の画像を `android-app/app/src/main/assets/different/` にコピー
4. 再ビルド

## フォルダ構成

```
android-app/
├── app/
│   ├── src/main/
│   │   ├── java/.../          # Kotlinソースコード
│   │   ├── res/               # レイアウト・リソース
│   │   └── assets/            # クイズ画像
│   │       ├── same/          # 同じもの同士の画像
│   │       └── different/     # 違うもの同士の画像
│   └── build.gradle.kts
├── build.gradle.kts
├── settings.gradle.kts
└── gradlew
```

## 画面構成

1. **ホーム画面**: スタートボタン、ベストスコア表示
2. **クイズ画面**: 画像表示、同じ/違うボタン、タイマー
3. **結果画面**: スコア、正解率、時間、問題別結果
