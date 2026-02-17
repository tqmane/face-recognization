# GPU 推論テストガイド

このガイドでは、各プラットフォームにおける GPU 推論実装のテスト手順を説明します。

## Windows でのテスト

### 前提条件
- DirectX 12 対応の Windows 10/11
- DirectML 対応の GPU（NVIDIA、AMD、または Intel）
- ONNX Runtime DirectML DLL（WINDOWS_DIRECTML_SETUP.md を参照）

### テストケース

#### TC1: DirectML 利用可否の検出
**手順**:
1. アプリを起動する
2. コンソール出力で GPU 機能を確認する

**期待される出力**:
```
=== GPU Capabilities ===
Platform: windows
TFLite GPU: false
DirectML: true
NNAPI: false
CoreML: false
TFLite devices: CPU
ONNX devices: CPU, XNNPACK, DirectML
=======================
```

#### TC2: ONNX DirectML エンジンの選択
**手順**:
1. 「ONNX DirectML (Windows)」エンジンを選択する
2. デバイスドロップダウンに CPU、XNNPACK、DirectML が表示されることを確認する
3. 「DirectML」デバイスを選択する
4. 「パフォーマンスチェック」をクリックする

**期待される結果**:
- エンジンが正常に初期化される
- 名前に「ModelName (ONNX-DirectML)」、またはフォールバック時に「(ONNX-XNNPACK)」が表示される
- 推論がエラーなく完了する

#### TC3: DirectML から XNNPACK へのフォールバック
**手順**:
1. DirectML DLL の名前を変更するか削除する
2. ONNX DirectML エンジンで DirectML デバイスを選択する
3. パフォーマンスチェックを実行する

**期待される結果**:
- コンソールに「DirectML requested but not directly supported」と表示される
- XNNPACK にフォールバックする
- エンジン名に「(ONNX-XNNPACK)」が表示される

#### TC4: パフォーマンス比較
**手順**:
1. CPU デバイスでパフォーマンスチェックを実行する（100回反復）
2. 平均レイテンシ（ms）を記録する
3. XNNPACK デバイスでパフォーマンスチェックを実行する
4. 平均レイテンシ（ms）を記録する
5. 結果を比較する

**期待される結果**:
- XNNPACK は CPU より2〜3倍高速であること
- DirectML（完全実装時）は5〜10倍高速であること

## Android でのテスト

### 前提条件
- GPU 搭載の Android デバイス
- NNAPI サポートには Android 8.0 以上が必要

### テストケース

#### TC5: TFLite GPU 利用可否
**手順**:
1. Android デバイスでアプリを起動する
2. コンソールで GPU 機能を確認する

**期待される出力**:
```
=== GPU Capabilities ===
Platform: android
TFLite GPU: true
DirectML: false
NNAPI: true
CoreML: false
TFLite devices: CPU, GPU
ONNX devices: CPU, XNNPACK, NNAPI
=======================
```

#### TC6: TFLite GPU デリゲート
**手順**:
1. 「TFLite (CPU/GPU)」エンジンを選択する
2. 「GPU」デバイスを選択する
3. パフォーマンスチェックを実行する

**期待される結果**:
- エンジン名に「ModelName (TFLite-GPU)」が表示される
- GPU 推論が CPU より3〜5倍高速であること
- 推論中にエラーが発生しないこと

#### TC7: ONNX NNAPI
**手順**:
1. 「ONNX Runtime」エンジンを選択する
2. 「NNAPI」デバイスを選択する
3. パフォーマンスチェックを実行する

**期待される結果**:
- エンジン名に「ModelName (ONNX-NNAPI)」が表示される
- 推論が正常に完了する
- パフォーマンスが CPU と同等またはそれ以上であること

#### TC8: Android での GPU フォールバック
**手順**:
1. Android エミュレーター（GPU サポートなし）で実行する
2. TFLite で GPU デバイスを選択する
3. パフォーマンスチェックを実行する

**期待される結果**:
- コンソールに「GPU delegate failed, falling back to CPU」と表示される
- エンジン名に「(TFLite-CPU)」が表示される
- 推論が正常に完了する

## iOS/macOS でのテスト

### 前提条件
- Apple Silicon または Intel GPU 搭載の macOS
- A シリーズチップ搭載の iOS デバイス

### テストケース

#### TC9: CoreML 利用可否
**手順**:
1. アプリを起動する
2. コンソールで機能を確認する

**期待される出力**:
```
=== GPU Capabilities ===
Platform: macos (or ios)
TFLite GPU: true
DirectML: false
NNAPI: false
CoreML: true
=======================
```

#### TC10: ONNX CoreML
**手順**:
1. 「ONNX Runtime」エンジンを選択する
2. 「CoreML」デバイスを選択する
3. パフォーマンスチェックを実行する

**期待される結果**:
- エンジン名に「(ONNX-CoreML)」が表示される
- 推論が Apple Neural Engine を使用する
- Apple デバイスで最高のパフォーマンスが得られる

## クロスプラットフォームテストケース

#### TC11: デバイス選択の保持
**手順**:
1. TFLite エンジンで GPU デバイスを選択する
2. ONNX エンジンに切り替える
3. ONNX で利用可能なデバイスにリセットされることを確認する
4. TFLite に戻す
5. 利用可能であれば、デバイス選択が保持されていることを確認する

**期待される結果**:
- エンジン変更時にデバイス選択が更新される
- クラッシュや無効なデバイス選択が発生しないこと

#### TC12: エラーハンドリング
**手順**:
1. GPU デバイスでエンジンを選択する
2. モデルファイルを削除する
3. エンジンの初期化を試みる

**期待される結果**:
- 明確なエラーメッセージが表示される
- アプリがクラッシュしないこと
- モデルをダウンロードすることで回復できること

#### TC13: 異なるデバイスでのベンチマーク
**手順**:
1. テストセットを読み込む
2. CPU デバイスでベンチマークを実行する
3. 精度とパフォーマンスを記録する
4. GPU デバイスでベンチマークを実行する
5. 結果を比較する

**期待される結果**:
- 精度は同一であること（±0.001）
- GPU の方が大幅に高速であること
- 両方とも正常に完了すること

## リソース管理テスト

#### TC14: 複数エンジンの初期化
**手順**:
1. TFLite エンジンを初期化する
2. パフォーマンスチェックを実行する
3. 戻って ONNX エンジンを選択する
4. 初期化してパフォーマンスチェックを実行する
5. 手順3〜4を繰り返す

**期待される結果**:
- メモリリークがないこと
- 各初期化が成功すること
- 「resource already released」エラーが発生しないこと

#### TC15: エンジンの高速切り替え
**手順**:
1. エンジンを複数回素早く切り替える
2. 各エンジンを初期化する
3. 破棄して新しいエンジンを作成する

**期待される結果**:
- クラッシュしないこと
- リソースが適切にクリーンアップされること
- OrtEnv シングルトンエラーが発生しないこと

## パフォーマンスベンチマーク

### 期待されるパフォーマンス範囲

#### モバイルデバイス
| デバイス | モデル | CPU (ms) | GPU (ms) | 高速化率 |
|----------|--------|----------|----------|----------|
| Pixel 6 | MobileNetV2 | ~50 | ~15 | 3.3x |
| iPhone 13 | MobileNetV2 | ~40 | ~10 | 4.0x |
| Galaxy S21 | MobileNetV2 | ~45 | ~12 | 3.7x |

#### デスクトップ
| デバイス | モデル | CPU (ms) | XNNPACK (ms) | DirectML (ms) |
|----------|--------|----------|--------------|---------------|
| i7 + RTX 3060 | MobileNetV2 | ~30 | ~15 | ~5* |
| Ryzen 5 + RX 580 | MobileNetV2 | ~35 | ~18 | ~7* |

*注: DirectML のパフォーマンスは完全実装待ちです

## 自動テスト

### ユニットテスト（将来の実装予定）

```dart
// テスト構造の例
void main() {
  group('GpuCapabilityChecker', () {
    test('detects platform correctly', () {
      final checker = GpuCapabilityChecker.instance;
      expect(checker.availableTfliteDevices.contains('CPU'), true);
    });
  });

  group('OnnxEngine', () {
    test('falls back to CPU on GPU failure', () async {
      final engine = OnnxEngine(
        modelName: 'test',
        modelPath: 'invalid',
        device: 'GPU',
      );
      // スローせず、フォールバックすること
      await expectLater(engine.initialize(), completes);
    });
  });
}
```

## 問題の報告

問題を報告する際は、以下の情報を含めてください：

1. **プラットフォーム情報**
   - OS バージョン（Windows 11、Android 12 など）
   - デバイスモデル
   - GPU モデル

2. **コンソールログ**
   - 完全な GPU 機能ログ
   - エラーメッセージ
   - エンジン初期化ログ

3. **再現手順**
   - 再現するための正確な手順
   - 選択したエンジンとデバイス
   - 期待される動作と実際の動作

4. **パフォーマンスデータ**
   - パフォーマンスチェックのレイテンシ数値
   - CPU ベースラインとの比較
   - 結果のスクリーンショット

## 成功基準

以下の条件を満たした場合、実装は成功と見なされます：

✅ すべてのプラットフォームで利用可能な GPU 機能が正しく検出されること
✅ デバイス選択 UI に利用可能なデバイスのみが表示されること
✅ GPU の初期化が成功するか、適切にフォールバックすること
✅ GPU でのパフォーマンス向上が測定可能であること
✅ 通常使用時にリソースリークやクラッシュが発生しないこと
✅ エラーメッセージが明確で対処可能であること
