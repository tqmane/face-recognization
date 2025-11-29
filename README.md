# Image Tester - 類似画像判別テスト

高校の総合探究で使用する、AIと人間の画像判別能力を比較するためのプロジェクトです。

## 概要

双子や似ている動物など、非常に似たものをAIと人間に判断させ、その正確性と速度を比較します。

## プロジェクト構成

```
image-tester/
├── tools/                    # Python画像収集ツール
│   ├── image_downloader.py   # 画像ダウンローダー
│   ├── requirements.txt
│   └── README.md
├── android-app/              # Androidテストアプリ
│   ├── app/src/main/
│   │   ├── java/...          # Kotlinソースコード
│   │   └── res/              # リソースファイル
│   └── build.gradle.kts
└── .github/workflows/        # GitHub Actions
    └── android-build.yml     # 自動ビルド設定
```

## 機能

### Androidアプリ

- **オフラインモード**: 端末内の画像でテスト
- **オンラインモード**: インターネットから画像を取得してテスト
  - テスト前に問題数を選択（5/10/15/20問）
  - 全画像を事前にダウンロードしてから計測開始
  - 純粋な判断時間のみを計測

### テスト内容

2枚の画像を表示し、「同じもの」か「違うもの」かを判断します。

- 正解: +10点
- 回答時間を記録
- 結果画面で詳細を確認

## セットアップ

### Python ツール

```bash
cd tools
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python image_downloader.py
```

### Android アプリ

GitHub Actionsで自動ビルドされます。
[Releases](../../releases) または [Actions](../../actions) からAPKをダウンロードできます。

#### ローカルビルド

```bash
cd android-app
./gradlew assembleDebug
```

## 技術スタック

- **Python**: icrawler, Pillow
- **Android**: Kotlin, Jsoup, Material Design 3
- **CI/CD**: GitHub Actions

## ライセンス

教育目的での使用を想定しています。
