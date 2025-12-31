# Engine test runner (WIP)

Minimal skeleton to run GPU/CPU inference on the same image set that humans use, and push the results to Firebase Realtime Database. Android優先で進める前提ですが、CLI構成なので他OSでも流用できます。

## フォルダ構成
- `pubspec.yaml` … Dart CLI 用の依存関係
- `bin/engine_test.dart` … エントリポイント
- `lib/engine/` … 推論エンジンの実装を差し替える場所（いまはモックのみ）
- `lib/models/` … マニフェスト・結果のモデル
- `lib/firebase_sync.dart` … RTDB へのアップロード/取得
- `sample_manifest.json` … マニフェストの例

## 事前準備
1. Dart SDK 3.x を用意（Flutter SDK があれば同梱の `dart` でOK）。
2. `cd engine-test && dart pub get`
3. Firebase RTDB 用の認証情報を環境変数で渡す:
   - `FIREBASE_DATABASE_URL` 例: `https://<project-id>-default-rtdb.firebaseio.com`
   - `FIREBASE_ID_TOKEN` … Firebase Auth で取得した ID トークン（ユーザーまたはカスタムトークンでサインインして取得）。  
     ※テスト用なのでサービスアカウントのカスタムトークンを使うか、既存アプリでログインして得た ID トークンを流用してください。

## マニフェスト
`sample_manifest.json` を参考に、同じ画像セットを列挙します。
```json
{
  "items": [
    { "id": "sample-cat", "path": "/absolute/or/relative/cat.jpg", "label": "cat" },
    { "id": "sample-dog", "path": "../sets_pics/dog.jpg", "label": "dog" }
  ]
}
```
- `path` はマニフェストファイルからの相対パスも利用可。
- 「人間と同じ条件」を守るためリサイズ・正規化は行いません（モデル側で許容することを前提）。

## 使い方（実行）
```
dart run bin/engine_test.dart \
  --manifest sample_manifest.json \
  --engine mock \
  --run-id test-run-001
```
- アップロード: `--database-url` と `--id-token` を明示するか、環境変数を使います。
- `--no-upload` を付けると Firebase へ送らずローカル出力のみ。
- `--output results.json` を付けると結果をファイルにも保存。
- 人間テスト用ZIPをそのまま使う:  
  ```
  dart run bin/engine_test.dart \
    --zip ../sets_pics/small_cats.zip \
    --engine mock \
    --run-id cat-run-001
  ```
  ZIP内の画像を一時ディレクトリへ無変換で展開し、ラベルはディレクトリ名を使用します（例: `british_shorthair/001.jpg` のラベルは `british_shorthair`）。
- 人間テストと同じ「セットID」で指定（自動ダウンロード）:  
  ```
  dart run bin/engine_test.dart \
    --set-id small_cats \
    --engine mock \
    --run-id cat-run-002
  ```
  `flutter-app` / `android-app` と同じ ZIP 一覧（dogs, small_cats, wild_dogs, raccoons, birds, marine, reptiles, bears, primates, insects）をそのまま利用します。
- 人間のテストと同じ問題生成ロジックを使う（問題数指定）:  
  ```
  dart run bin/engine_test.dart \
    --set-id small_cats \
    --question-count 10 \
    --engine mock \
    --run-id cat-run-003 \
    --seed 42 \
    --verbose
  ```
  - `--question-count` に 5/10/15/20 などを指定すると、Flutter/Android と同じペア生成ロジック（similar_pairs優先＋同じ/違うを半々）で問題を作ります。  
  - `--seed` を指定するとランダムを固定できます。  
  - 各問題は画像2枚分のレコードとして `runs/{runId}/qN_1` / `qN_2` に保存し、メタ情報に `questionIndex`, `isSame`, `type1`, `type2`, `position` が入ります。

## 使い方（確認/取得）
すでに Firebase RTDB にある結果を取得して確認できます（ローカル保存も可能）。
```
dart run bin/engine_test.dart \
  --mode fetch \
  --run-id test-run-001 \
  --database-url "$FIREBASE_DATABASE_URL" \
  --id-token "$FIREBASE_ID_TOKEN" \
  --output fetched_results.json \
  --verbose
```
- `--image-id <id>` を付けると特定の1件だけ取得します。
- `--verbose` で内容を標準出力に一覧表示します。

## エンジンの差し替え
- `lib/engine/engine.dart` にインターフェースがあります。
- `lib/engine/mock_engine.dart` を参考に、ONNX Runtime / TFLite などの実装を追加し、`_resolveEngine` に登録してください。
- プラットフォームごとに FFI でネイティブライブラリを呼び出す構成を想定しています。

## Firebase 書き込み形式（RTDB）
`runs/{runId}/{imageId}` に以下のJSONを書き込みます:
```json
{
  "runId": "test-run-001",
  "imageId": "sample-cat",
  "engine": "mock",
  "provider": "cpu",
  "latencyMs": 12,
  "predictions": [{ "label": "mock", "score": 1.0 }],
  "inputSize": null,
  "preprocess": "none (match human test)",
  "label": "cat",
  "meta": {},
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## 今後の実装ポイント
- Android優先で、FFI経由で GPU 対応エンジンを実装
- 前処理なしで動くモデルを準備（動的入力/許容のあるモデルを推奨）
- Firebase Auth のトークン取得を自動化したい場合は、既存のアプリやカスタムトークン発行を流用
