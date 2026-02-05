import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'inference_engine.dart';
import '../services/performance_benchmark.dart';

/// GPU推論サーバーに接続するエンジン
/// Windows (DirectML) / Linux (CUDA) でGPUアクセラレーションを利用
class GpuServerEngine implements InferenceEngine {
  final String _modelName;
  final String _modelPath;
  final int _inputSize;
  final String _serverUrl;

  bool _modelLoaded = false;
  String _provider = 'CPU';

  GpuServerEngine({
    required String modelName,
    required String modelPath,
    int inputSize = 224,
    String serverUrl = 'http://127.0.0.1:8765',
  })  : _modelName = modelName,
        _modelPath = modelPath,
        _inputSize = inputSize,
        _serverUrl = serverUrl;

  @override
  String get name => '$_modelName (GPU Server - $_provider)';

  /// サーバーが起動しているか確認
  static Future<bool> isServerRunning({String serverUrl = 'http://127.0.0.1:8765'}) async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 利用可能なプロバイダーを取得
  static Future<Map<String, dynamic>?> getProviders({String serverUrl = 'http://127.0.0.1:8765'}) async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/providers'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('プロバイダー取得エラー: $e');
    }
    return null;
  }

  /// GPUが利用可能か (サーバー経由)
  static Future<bool> isGpuAvailable({String serverUrl = 'http://127.0.0.1:8765'}) async {
    final providers = await getProviders(serverUrl: serverUrl);
    if (providers == null) return false;
    
    final recommended = providers['recommended'] as String?;
    return recommended != null && !recommended.contains('CPU');
  }

  @override
  Future<void> initialize() async {
    try {
      // サーバーのヘルスチェック
      final running = await isServerRunning(serverUrl: _serverUrl);
      if (!running) {
        throw Exception('GPU推論サーバーが起動していません。\n'
            'サーバーを起動してください:\n'
            '  cd ai_benchmark/server\n'
            '  python inference_server.py');
      }

      // モデル読み込み
      final uri = Uri.parse('$_serverUrl/load')
          .replace(queryParameters: {
        'model_path': _modelPath,
        'input_size': _inputSize.toString(),
        'provider': 'auto',
      });

      final response = await http.post(uri);

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'モデル読み込み失敗');
      }

      final result = jsonDecode(response.body);
      _modelLoaded = result['success'] == true;
      _provider = result['model']?['provider'] ?? 'CPU';

      debugPrint('GPU Server: モデル読み込み完了 ($_provider)');
    } catch (e) {
      debugPrint('GPU Server 初期化エラー: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    // サーバーは維持するので、モデルのアンロードのみ
    _unloadModel();
    _modelLoaded = false;
  }

  Future<void> _unloadModel() async {
    try {
      await http.post(Uri.parse('$_serverUrl/unload'));
      debugPrint('モデルをアンロードしました');
    } catch (e) {
      debugPrint('モデルアンロードエラー: $e');
    }
  }

  @override
  Future<double> compareImages(String imagePath1, String imagePath2) async {
    if (!_modelLoaded) {
      throw Exception('モデルが読み込まれていません');
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/compare'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_path1': imagePath1,
          'image_path2': imagePath2,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '比較失敗');
      }

      final result = jsonDecode(response.body);
      return (result['similarity'] as num).toDouble();
    } catch (e) {
      debugPrint('画像比較エラー: $e');
      return 0.0;
    }
  }

  @override
  Future<BenchmarkStats> runSyntheticBenchmark({
    int warmupRuns = 30,
    int runs = 200,
  }) async {
    if (!_modelLoaded) {
      throw Exception('モデルが読み込まれていません');
    }

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/benchmark'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warmup_runs': warmupRuns,
          'runs': runs,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'ベンチマーク失敗');
      }

      final result = jsonDecode(response.body);
      return BenchmarkStats(
        runs: result['runs'] as int,
        meanMs: (result['mean_ms'] as num).toDouble(),
        p50Ms: (result['p50_ms'] as num).toDouble(),
        p90Ms: (result['p90_ms'] as num).toDouble(),
        minMs: (result['min_ms'] as num).toDouble(),
        maxMs: (result['max_ms'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('ベンチマークエラー: $e');
      return const BenchmarkStats(
        runs: 0,
        meanMs: 0,
        p50Ms: 0,
        p90Ms: 0,
        minMs: 0,
        maxMs: 0,
      );
    }
  }

  /// 単一画像の埋め込みベクトルを取得
  Future<List<double>?> getEmbedding(String imagePath) async {
    if (!_modelLoaded) return null;

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/infer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_path': imagePath}),
      );

      if (response.statusCode != 200) return null;

      final result = jsonDecode(response.body);
      final embedding = result['embedding'] as List<dynamic>;
      return embedding.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      debugPrint('埋め込み取得エラー: $e');
      return null;
    }
  }
}
