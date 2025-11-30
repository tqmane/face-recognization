# 判別クイズ Android アプリ

似ているものが「同じ」か「違う」かを判断するクイズアプリです。
2枚の画像を見て、同一のものか、似ているが別のもの（双子、そっくりさん、似た動物など）かを判断します。

## 機能

- 🎮 **オンラインモード**: リアルタイムで画像を取得してクイズ
- 📁 **テストセットモード**: 事前にダウンロードした画像セットでオフラインプレイ
- 📊 **履歴機能**: 過去のクイズ結果を確認
- 🌙 **ダークモード対応**: システム設定に連動
- ⏱️ 時間計測（合計・各問題）
- 🏆 ベストスコア保存

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

## ディレクトリ構造

```
android-app/
├── app/
│   ├── src/main/
│   │   ├── java/com/tqmane/similarityquiz/
│   │   │   ├── MainActivity.kt          # ホーム画面
│   │   │   ├── OnlineQuizActivity.kt    # オンラインクイズ画面
│   │   │   ├── ResultActivity.kt        # 結果表示画面
│   │   │   ├── TestSetActivity.kt       # テストセット管理画面
│   │   │   ├── HistoryActivity.kt       # 履歴画面
│   │   │   │
│   │   │   ├── OnlineQuizManager.kt     # クイズの問題生成・管理
│   │   │   ├── ReliableImageSource.kt   # 信頼性の高い画像ソース
│   │   │   ├── ImageScraper.kt          # Bing画像検索（フォールバック）
│   │   │   ├── TestSetManager.kt        # テストセットの保存・読み込み
│   │   │   │
│   │   │   ├── QuizResult.kt            # クイズ結果データクラス
│   │   │   ├── DownloadService.kt       # バックグラウンドダウンロードサービス
│   │   │   └── DownloadNotificationHelper.kt # 通知ヘルパー
│   │   │
│   │   ├── res/
│   │   │   ├── layout/                  # スマートフォン用レイアウト
│   │   │   ├── layout-sw600dp/          # タブレット用レイアウト
│   │   │   ├── values/                  # ライトモード用リソース
│   │   │   ├── values-night/            # ダークモード用リソース
│   │   │   ├── drawable/                # 画像・背景リソース
│   │   │   └── mipmap-*/                # アプリアイコン
│   │   │
│   │   └── AndroidManifest.xml          # アプリ設定・権限
│   │
│   └── build.gradle.kts                 # アプリのビルド設定
│
└── build.gradle.kts                     # プロジェクトのビルド設定
```

## 主要コンポーネント

### OnlineQuizManager.kt
クイズの問題を生成するマネージャークラス。

- **ジャンル管理**: 17種類のジャンル（ネコ科、犬種、霊長類、車など）
- **問題生成**: ランダムに「同じ」or「違う」問題を生成
- **データ定義**: 100以上のアイテムと類似ペアの定義

### ReliableImageSource.kt
信頼性の高いAPIから画像を取得するクラス。

**使用API（優先順）:**
1. **iNaturalist** - 野生動物の研究グレード写真
2. **GBIF** - 自然史博物館等の生物多様性データ
3. **The Dog API** - 犬種ごとの写真
4. **The Cat API** - 猫種ごとの写真
5. **Unsplash** - 高品質な写真（車など）
6. **Wikimedia Commons** - その他（ロゴなど）

### ImageScraper.kt
Bing画像検索を使用したフォールバック用画像取得クラス。

- 写真フィルタリング（イラスト除外）
- 並列ダウンロード
- キャッシュ機能

### TestSetManager.kt
テストセットの作成・保存・読み込みを管理。

- 画像をローカルに保存
- メタデータ（JSON）で管理
- オフラインでのクイズを実現

## データフロー

```
[ユーザー操作]
      ↓
[OnlineQuizActivity]
      ↓
[OnlineQuizManager] → 問題設定を生成
      ↓
[ReliableImageSource] → API から画像URL取得
      ↓ (取得失敗時)
[ImageScraper] → Bing検索でフォールバック
      ↓
[画像ダウンロード・合成]
      ↓
[クイズ表示]
      ↓
[ResultActivity] → 結果表示
```

## 必要な権限

- `INTERNET` - 画像のダウンロード
- `ACCESS_NETWORK_STATE` - ネットワーク状態の確認
- `POST_NOTIFICATIONS` - ダウンロード進捗通知
- `FOREGROUND_SERVICE` - バックグラウンドダウンロード
- `WAKE_LOCK` - ダウンロード中のスリープ防止

## 技術スタック

- **言語**: Kotlin
- **UI**: Material Design 3, CardView, RecyclerView
- **非同期処理**: Kotlin Coroutines
- **ネットワーク**: OkHttp, Jsoup
- **JSON**: org.json

## 画面構成

1. **ホーム画面**: ジャンル選択、スタートボタン、ベストスコア表示
2. **クイズ画面**: 画像表示、同じ/違うボタン、タイマー
3. **結果画面**: スコア、正解率、時間、問題別結果
4. **テストセット画面**: オフラインセットの管理
5. **履歴画面**: 過去の結果一覧

---

*このアプリは日本の高等学校における総合探究の研究プロジェクトとして開発されました。*
