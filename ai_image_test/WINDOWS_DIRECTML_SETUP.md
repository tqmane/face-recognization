# Windows DirectML セットアップガイド

## DirectML サポートの前提条件

Windows 上で DirectML を使用して GPU アクセラレーションを利用するには、DirectML サポート付きの ONNX Runtime をインストールする必要があります。

### オプション 1: ONNX Runtime DirectML DLL（本番環境向け推奨）

1. **ONNX Runtime DirectML のダウンロード**
   - [ONNX Runtime Releases](https://github.com/microsoft/onnxruntime/releases) にアクセスしてください
   - 最新の `onnxruntime-win-x64-gpu-*.zip`（DirectML 同梱）をダウンロードしてください
   - または DirectML 専用ビルドの `onnxruntime-directml-*.zip` をダウンロードしてください

2. **DLL の展開と配置**
   ```
   zipファイルを展開し、以下のファイルをWindowsのPATHまたはアプリのディレクトリにコピーしてください:
   - onnxruntime.dll（または onnxruntime-directml.dll）
   - DirectML.dll
   ```

3. **システム PATH への追加**
   - オプション A: DLL を `C:\Windows\System32` にコピーする
   - オプション B: 展開したディレクトリをシステム PATH に追加する
   - オプション C: DLL を Flutter アプリの実行ファイルと同じディレクトリに配置する

### オプション 2: Python ONNX Runtime（テスト用の代替方法）

Python がインストールされている場合、Python ONNX Runtime をバックエンドとして使用できます:

```bash
pip install onnxruntime-directml
```

その後、Python ブリッジまたはサブプロセスを使用して推論を処理します（追加の実装が必要です）。

## DirectML サポートの確認

### GPU の利用可否を確認する

1. **Windows デバイスマネージャーを使用する**
   - デバイスマネージャーを開く（Win + X → デバイスマネージャー）
   - 「ディスプレイ アダプター」を展開する
   - GPU が表示され、有効になっていることを確認する

2. **DirectX 診断ツールを使用する**
   ```
   Win + R → dxdiag
   ```
   - 「ディスプレイ」タブに移動する
   - DirectX のバージョンを確認する（DirectML には 12 以上が必要）

3. **アプリのログを使用する**
   - ai_image_test アプリを実行する
   - コンソール出力で以下を確認する:
     ```
     === GPU Capabilities ===
     Platform: windows
     DirectML: true
     ```

## サポートされている GPU

DirectML は幅広い GPU をサポートしています:
- **NVIDIA**: GeForce GTX 900 シリーズ以降
- **AMD**: Radeon RX 400 シリーズ以降
- **Intel**: Intel HD Graphics 600 シリーズ以降
- DirectX 12 のサポートが必要

## トラブルシューティング

### DirectML が利用できない

**症状**: アプリに「DirectML not available」と表示されるか、CPU/XNNPACK にフォールバックする

**解決策**:
1. DLL が PATH に存在するか確認する
   ```cmd
   where onnxruntime.dll
   where DirectML.dll
   ```

2. DirectX のバージョンを確認する
   ```cmd
   dxdiag
   ```
   - DirectX 12 以上である必要があります

3. GPU ドライバーを更新する
   - NVIDIA: [nvidia.com/drivers](https://www.nvidia.com/drivers)
   - AMD: [amd.com/support](https://www.amd.com/support)
   - Intel: [intel.com/graphics](https://www.intel.com/content/www/us/en/download-center/home.html)

### パフォーマンスの問題

**症状**: GPU 推論が期待より遅い

**解決策**:
1. GPU 使用率を確認する
   - タスクマネージャーを使用する（パフォーマンスタブ → GPU）
   - 推論中に GPU のアクティビティが表示されるべきです

2. DirectML が使用されていることを確認する
   - アプリのログで「ONNX-DirectML」または「ONNX-XNNPACK」を確認する
   - DirectML は CPU よりも優れたパフォーマンスを示すべきです

3. モデルの最適化
   - モデルが ONNX 形式（TFLite ではなく）であることを確認する
   - GPU パフォーマンス向上のために fp16 モデルを使用する（サポートされている場合）

### DLL 読み込みエラー

**症状**: 「Failed to load onnxruntime.dll」

**解決策**:
1. Visual C++ 再頒布可能パッケージをインストールする
   - [Microsoft](https://aka.ms/vs/17/release/vc_redist.x64.exe) からダウンロードしてください

2. DLL のアーキテクチャを確認する
   - 64 ビット Windows には 64 ビット DLL を使用する
   - Flutter ビルドとアーキテクチャを一致させる

## 現在の制限事項

1. **パッケージの制限**: 現在の Dart `onnxruntime` パッケージ（v1.4.1）は DirectML 実行プロバイダーを直接公開していません
   - アプリは現在、最適化されたフォールバックとして XNNPACK を使用しています
   - 完全な DirectML サポートにはカスタム FFI 実装またはパッケージの更新が必要です

2. **回避策**: 実装は FFI を介して DirectML の利用可否を確認しますが、実際の推論には XNNPACK にフォールバックします

## 将来の実装

完全な DirectML サポートを実現するには、以下のいずれかのアプローチが必要です:

1. **カスタム FFI バインディング**
   - ONNX Runtime C API への完全な FFI バインディングを実装する
   - DirectML 実行プロバイダーを手動で設定する
   - メモリ管理とテンソル操作を処理する

2. **パッケージの更新**
   - onnxruntime Dart パッケージが DirectML サポートを追加するのを待つ
   - 利用可能になったら実装を更新する

3. **ネイティブプラグイン**
   - Flutter プラットフォームチャネルを作成する
   - ネイティブ Windows C++ コードで DirectML 推論を実装する
   - 結果を Dart にブリッジする

## パフォーマンス比較

Windows 上の DirectML による予想されるパフォーマンス向上:

| デバイス       | 相対パフォーマンス |
|--------------|---------------------|
| CPU          | 1x（基準値）       |
| XNNPACK      | 2〜3 倍高速        |
| DirectML GPU | 5〜10 倍高速       |

実際のパフォーマンスは以下の要因によって異なります:
- GPU モデルとメモリ
- モデルのサイズと複雑さ
- 入力画像のサイズ
- バッチサイズ

## その他のリソース

- [DirectML 概要](https://docs.microsoft.com/en-us/windows/ai/directml/dml)
- [ONNX Runtime ドキュメント](https://onnxruntime.ai/docs/)
- [DirectML パフォーマンスガイド](https://docs.microsoft.com/en-us/windows/ai/directml/dml-performance)
