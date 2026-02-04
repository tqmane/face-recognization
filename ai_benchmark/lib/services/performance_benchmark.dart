import 'dart:math';

class BenchmarkStats {
  final int runs;
  final double meanMs;
  final double p50Ms;
  final double p90Ms;
  final double minMs;
  final double maxMs;

  const BenchmarkStats({
    required this.runs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.minMs,
    required this.maxMs,
  });

  double get fps => meanMs <= 0 ? 0 : 1000.0 / meanMs;
}

BenchmarkStats computeBenchmarkStats(List<double> samplesMs) {
  if (samplesMs.isEmpty) {
    return const BenchmarkStats(
      runs: 0,
      meanMs: 0,
      p50Ms: 0,
      p90Ms: 0,
      minMs: 0,
      maxMs: 0,
    );
  }

  final sorted = [...samplesMs]..sort();
  final runs = sorted.length;
  final mean = sorted.reduce((a, b) => a + b) / runs;

  double percentile(double p) {
    if (runs == 1) return sorted.first;
    final idx = (p * (runs - 1)).clamp(0, runs - 1);
    final lo = idx.floor();
    final hi = idx.ceil();
    if (lo == hi) return sorted[lo];
    final t = idx - lo;
    return sorted[lo] * (1 - t) + sorted[hi] * t;
  }

  final minV = sorted.first;
  final maxV = sorted.last;

  return BenchmarkStats(
    runs: runs,
    meanMs: mean,
    p50Ms: percentile(0.50),
    p90Ms: percentile(0.90),
    minMs: minV,
    maxMs: maxV,
  );
}

String formatMs(double ms) {
  if (ms.isNaN || ms.isInfinite) return '-';
  final v = max(0.0, ms);
  return v.toStringAsFixed(v < 10 ? 2 : 1);
}
