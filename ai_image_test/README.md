# AI Image Test

画像ペアの類似度をAI推論エンジンで判定し、パフォーマンスを計測するベンチマークアプリ。

## 機能

- **4つの推論エンジン**: Histogram (ベースライン), TFLite (CPU/GPU), ONNX Runtime, GPU Server (リモート)
- **5プラットフォーム対応**: Android, iOS, Linux, Windows, macOS
- **テストセット読み込み**: ZIP / フォルダから manifest.json + 画像サブフォルダ
- **詳細なデータ出力**: JSON / CSV で問題単位の結果をエクスポート（学術研究向け）
- **パフォーマンスチェック**: テスト画像不要の合成ベンチマーク (Mean, P50, P90, FPS)

## テストセット構造

```
test_set/
  manifest.json          (オプション)
  species_a/
    img001.jpg
    img002.jpg
  species_b/
    img001.jpg
    img002.jpg
```

`manifest.json` 例:
```json
{
  "genre": "bears",
  "similar_pairs": [
    {"id1": "grizzly", "id2": "kodiak"}
  ]
}
```

## ビルド

```bash
cd ai_image_test
flutter pub get

# Linux
flutter build linux --release

# Android
flutter build apk --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# iOS
flutter build ios --release --no-codesign
```

## モデル

モデル管理画面から TFLite / ONNX モデルをダウンロードできます。
GitHub Releases (`models-v1` タグ) からも手動取得可能です。

## エンジン別の特徴

| エンジン | GPU使用 | モデル必要 | 備考 |
|---|---|---|---|
| Histogram | No | No | 色ヒストグラムのコサイン類似度（ベースライン） |
| TFLite | Yes (Mobile) | Yes | Metal (Apple) / OpenCL (Android) |
| ONNX Runtime | Partial | Yes | CoreML / NNAPI / XNNPACK |
| GPU Server | Yes (Desktop) | Server側 | CUDA / DirectML対応のFastAPIサーバー |

## CI/CD

GitHub Actions で全5プラットフォームの自動ビルドを実行。
`v*` タグをプッシュすると GitHub Release として成果物がアップロードされます。
