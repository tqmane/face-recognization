import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/benchmark_run.dart';
import 'engine.dart';

/// Baseline engine: compares colour histograms (no model needed).
class HistogramEngine implements InferenceEngine {
  @override
  String get name => 'Color Histogram (CPU)';

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {}

  @override
  Future<double> compareImages(String path1, String path2) async {
    final a = await _loadImage(path1);
    final b = await _loadImage(path2);
    if (a == null || b == null) return 0;
    return _cosine(_histogram(a), _histogram(b));
  }

  // --- internals ---

  Future<img.Image?> _loadImage(String p) async {
    try {
      return img.decodeImage(await File(p).readAsBytes());
    } catch (e) {
      debugPrint('HistogramEngine: load error: $p $e');
      return null;
    }
  }

  List<double> _histogram(img.Image image) {
    final bins = List<double>.filled(512, 0);
    for (final px in image) {
      final idx =
          ((px.r.toInt() >> 5) << 6) | ((px.g.toInt() >> 5) << 3) | (px.b.toInt() >> 5);
      bins[idx]++;
    }
    final n = image.width * image.height;
    for (int i = 0; i < bins.length; i++) bins[i] /= n;
    return bins;
  }

  double _cosine(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  @override
  Future<PerfStats> runSyntheticBenchmark({int warmupRuns = 30, int runs = 200}) async {
    final dummy = List<double>.filled(512, 1.0 / 512);
    final times = <double>[];
    for (int i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      _cosine(dummy, dummy);
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000.0);
    }
    times.sort();
    return PerfStats(
      runs: runs,
      meanMs: times.reduce((a, b) => a + b) / times.length,
      p50Ms: times[(times.length * 0.5).floor()],
      p90Ms: times[(times.length * 0.9).floor()],
      minMs: times.first,
      maxMs: times.last,
    );
  }
}
