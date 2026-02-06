import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../engines/engine.dart';
import '../models/benchmark_run.dart';

/// GPU Server engine – delegates inference to a Python FastAPI server
/// running on localhost (or a remote machine) that uses CUDA / DirectML.
///
/// The server exposes:
///   POST /compare   { "image1": <base64>, "image2": <base64> }
///   → { "similarity": 0.83, "inference_ms": 12 }
///
///   GET  /health    → { "status": "ok", "device": "cuda" }
class GpuServerEngine extends InferenceEngine {
  GpuServerEngine({this.serverUrl = 'http://localhost:8000'});

  final String serverUrl;
  String _device = 'unknown';

  @override
  String get name => 'GPU Server ($_device)';

  @override
  Future<void> initialize() async {
    // Probe server health.
    try {
      final res = await http.get(Uri.parse('$serverUrl/health')).timeout(
        const Duration(seconds: 5),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _device = body['device'] as String? ?? 'gpu';
        debugPrint('GpuServerEngine: connected – device=$_device');
      } else {
        throw Exception('GPU Server returned ${res.statusCode}');
      }
    } catch (e) {
      throw Exception(
          'GPU Server に接続できませんでした ($serverUrl): $e\n'
          'サーバーを起動してから再試行してください。');
    }
  }

  @override
  Future<double> compareImages(String imagePath1, String imagePath2) async {
    final img1 = base64Encode(await File(imagePath1).readAsBytes());
    final img2 = base64Encode(await File(imagePath2).readAsBytes());

    final res = await http.post(
      Uri.parse('$serverUrl/compare'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image1': img1, 'image2': img2}),
    );

    if (res.statusCode != 200) {
      throw Exception('GPU Server /compare error: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['similarity'] as num).toDouble();
  }

  @override
  Future<PerfStats> runSyntheticBenchmark({int warmupRuns = 30, int runs = 200}) async {
    // GPU Server synthetic benchmark: send request to server.
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/benchmark'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'iterations': runs}),
      ).timeout(const Duration(seconds: 120));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final times = (body['times_ms'] as List).cast<num>().map((n) => n.toDouble()).toList();
        return PerfStats.fromTimes(times);
      }
    } catch (_) {
      debugPrint('GpuServerEngine: /benchmark not available, skipping');
    }

    // Fallback: no synthetic benchmark for remote server.
    return const PerfStats(runs: 0, meanMs: 0, p50Ms: 0, p90Ms: 0, minMs: 0, maxMs: 0);
  }

  @override
  Future<void> dispose() async {
    // Nothing to clean up.
  }
}
