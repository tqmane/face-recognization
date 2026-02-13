# AI Image Test

画像ペアの類似度をAI推論エンジンで判定し、パフォーマンスを計測するベンチマークアプリ。

## 機能

- **5つの推論エンジン**: Histogram (ベースライン), TFLite (CPU/GPU), ONNX Runtime, ONNX DirectML (Windows), GPU Server (リモート)
- **5プラットフォーム対応**: Android, iOS, Linux, Windows, macOS
- **GPU アクセラレーション**: 
  - Windows: DirectML (NVIDIA/AMD/Intel GPU)
  - Android: TFLite GPU Delegate V2, ONNX NNAPI
  - iOS/macOS: Metal, CoreML
- **デバイス選択**: プラットフォームごとに利用可能なデバイス（CPU, GPU, DirectML, NNAPI, CoreML, XNNPACK）を選択可能
- **自動フォールバック**: GPU 初期化失敗時に自動的に CPU にフォールバック
- **テストセット読み込み**: ZIP / フォルダから manifest.json + 画像サブフォルダ
- **詳細なデータ出力**: JSON / CSV で問題単位の結果をエクスポート（学術研究向け）
- **パフォーマンスチェック**: テスト画像不要の合成ベンチマーク (Mean, P50, P90, FPS)

## 📚 ドキュメント

- **[GPU_SUPPORT.md](GPU_SUPPORT.md)**: GPU サポートの実装詳細
- **[WINDOWS_DIRECTML_SETUP.md](WINDOWS_DIRECTML_SETUP.md)**: Windows DirectML のセットアップ手順
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)**: プラットフォーム別テストガイド

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

## GPU 使用のクイックスタート

### Windows で DirectML を使用する場合

1. ONNX Runtime DirectML DLL をインストール（詳細は [WINDOWS_DIRECTML_SETUP.md](WINDOWS_DIRECTML_SETUP.md)）
2. アプリ起動後、「ONNX DirectML (Windows)」を選択
3. デバイスで「DirectML」を選択
4. パフォーマンスチェックまたはベンチマークを実行

### Android で GPU を使用する場合

1. 「TFLite (CPU/GPU)」または「ONNX Runtime」を選択
2. デバイスで「GPU」（TFLite）または「NNAPI」（ONNX）を選択
3. ベンチマークを実行して GPU アクセラレーションを確認

### iOS/macOS で GPU を使用する場合

1. 「ONNX Runtime」を選択
2. デバイスで「CoreML」を選択
3. Apple Neural Engine を活用した高速推論を実行

## モデル

モデル管理画面から TFLite / ONNX モデルをダウンロードできます。
GitHub Releases (`models-v1` タグ) からも手動取得可能です。

## エンジン別の特徴

| エンジン | GPU使用 | モデル必要 | 備考 |
|---|---|---|---|
| Histogram | No | No | 色ヒストグラムのコサイン類似度（ベースライン） |
| TFLite | Yes (Mobile/macOS) | Yes | GPU Delegate V2 (Android), Metal (iOS/macOS) |
| ONNX Runtime | Partial | Yes | CoreML (Apple) / NNAPI (Android) / XNNPACK |
| ONNX DirectML | Yes (Windows) | Yes | DirectML for NVIDIA/AMD/Intel GPUs on Windows |
| GPU Server | Yes (Desktop) | Server側 | CUDA / DirectML対応のFastAPIサーバー |

## プラットフォーム別 GPU サポート

### Windows
- **ONNX DirectML**: DirectML 経由で GPU アクセラレーション (NVIDIA/AMD/Intel)
- **ONNX XNNPACK**: CPU 最適化版（DirectML 非対応時の代替）
- **TFLite**: CPU のみ

### Android
- **TFLite GPU**: GPU Delegate V2 によるモバイル GPU 加速
- **ONNX NNAPI**: Android Neural Networks API
- **ONNX XNNPACK**: CPU 最適化版

### iOS/macOS
- **TFLite GPU**: Metal によるハードウェアアクセラレーション
- **ONNX CoreML**: Apple Neural Engine / GPU
- **ONNX XNNPACK**: CPU 最適化版

詳細は [GPU_SUPPORT.md](GPU_SUPPORT.md) を参照してください。

## CI/CD

GitHub Actions で全5プラットフォームの自動ビルドを実行。
`v*` タグをプッシュすると GitHub Release として成果物がアップロードされます。
