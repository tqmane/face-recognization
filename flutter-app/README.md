# Flutter判別クイズアプリ

Windows/Mac/Linux/Android/iOS対応のクロスプラットフォーム版「判別クイズ」アプリです。
このアプリは主に**デスクトップ（Windows/Mac/Linux）での研究用テスト**を目的として開発されました。

## 機能

- 🎮 **オンラインモード**: リアルタイムで画像を取得してクイズ
- 📦 **テストセットモード**: 事前ダウンロードした画像でオフラインテスト
- 📊 **結果のエクスポート**: CSV形式でテスト結果を出力
- 🎯 **17種類のジャンル**: ネコ科、犬種、車、ロゴなど
- 🌙 **ダークモード対応**: システム設定に連動

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
# Windows（推奨）
flutter run -d windows

# Mac
flutter run -d macos

# Linux
flutter run -d linux
```

### ビルド

```bash
# Windows
flutter build windows

# Mac
flutter build macos

# Linux
flutter build linux
```

## ディレクトリ構造

```
flutter-app/
├── lib/
│   ├── main.dart                    # エントリポイント
│   ├── screens/
│   │   ├── home_screen.dart         # ホーム画面
│   │   ├── online_quiz_screen.dart  # オンラインクイズ画面
│   │   ├── test_set_screen.dart     # テストセット管理画面
│   │   └── quiz_screen.dart         # クイズ実行画面
│   │
│   ├── services/
│   │   ├── image_search_service.dart # 画像検索サービス
│   │   ├── inaturalist_service.dart  # iNaturalist API
│   │   ├── gbif_service.dart         # GBIF API
│   │   ├── dog_api_service.dart      # Dog API
│   │   ├── cat_api_service.dart      # Cat API
│   │   ├── wikimedia_service.dart    # Wikimedia Commons API
│   │   └── test_set_service.dart     # テストセット管理
│   │
│   ├── models/
│   │   ├── quiz_question.dart        # 問題データモデル
│   │   ├── quiz_result.dart          # 結果データモデル
│   │   └── genre.dart                # ジャンル定義
│   │
│   └── widgets/                      # 再利用可能なUIコンポーネント
│
├── assets/                           # アイコン等のアセット
├── windows/                          # Windows固有の設定
├── macos/                            # macOS固有の設定
├── linux/                            # Linux固有の設定
└── pubspec.yaml                      # 依存関係の定義
```

## 主要コンポーネント

### ImageSearchService
複数のAPIソースから画像を取得する統合サービス。

**使用API（優先順）:**
1. **iNaturalist** - 野生動物の研究グレード写真
2. **GBIF** - 自然史博物館等の生物多様性データ
3. **The Dog API** - 犬種ごとの写真
4. **The Cat API** - 猫種ごとの写真
5. **Wikimedia Commons** - その他（ロゴなど）
6. **Bing画像検索** - フォールバック

### TestSetService
テストセットの作成・保存・読み込みを管理。

- 画像をローカルに保存
- JSON形式でメタデータ管理
- 結果のCSVエクスポート機能

### Genre
17種類のジャンルを定義。

- ネコ科大型・小型
- 犬種・野生イヌ科
- アライグマ系・鳥類・海洋動物
- 爬虫類・クマ科・霊長類
- 昆虫・似ている人・車・ロゴ

## データフロー

```
[ユーザー操作]
      ↓
[HomeScreen] → ジャンル選択
      ↓
[OnlineQuizScreen] または [TestSetScreen]
      ↓
[ImageSearchService] → 複数APIから画像取得
      ↓
[QuizScreen] → クイズ実行
      ↓
[結果表示 + CSVエクスポート]
```

## 技術スタック

- **言語**: Dart 3.0+
- **フレームワーク**: Flutter 3.0+
- **HTTP**: http パッケージ
- **ローカルストレージ**: path_provider, shared_preferences
- **ファイル操作**: dart:io

## 研究での使い方

### テストセットの作成
1. ホーム画面で「テストセット」を選択
2. ジャンルと問題数を選択
3. 「ダウンロード」をクリック
4. 画像がローカルに保存される

### テストの実施
1. 保存されたテストセットを選択
2. 「開始」をクリック
3. クイズに回答
4. 終了後、結果がCSVでエクスポート可能

### 結果の分析
CSVファイルには以下の情報が含まれます：
- 問題番号
- ジャンル
- 正解（同じ/違う）
- 回答（同じ/違う）
- 正誤
- 回答時間（ミリ秒）

---

*このアプリは日本の高等学校における総合探究の研究プロジェクトとして開発されました。*
