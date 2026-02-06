import 'inference_result.dart';

/// Summary of a complete benchmark run.
class BenchmarkRun {
  final String runId;
  final DateTime timestamp;
  final String engineName;
  final String device;
  final int threads;
  final String testSetName;
  final double threshold;
  final int totalQuestions;
  final int correctCount;
  final double accuracy;
  final int totalTimeMs;
  final double avgInferenceTimeMs;
  final List<InferenceResult> results;

  const BenchmarkRun({
    required this.runId,
    required this.timestamp,
    required this.engineName,
    required this.device,
    required this.threads,
    required this.testSetName,
    required this.threshold,
    required this.totalQuestions,
    required this.correctCount,
    required this.accuracy,
    required this.totalTimeMs,
    required this.avgInferenceTimeMs,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'timestamp': timestamp.toIso8601String(),
        'engineName': engineName,
        'device': device,
        'threads': threads,
        'testSetName': testSetName,
        'threshold': threshold,
        'totalQuestions': totalQuestions,
        'correctCount': correctCount,
        'accuracy': accuracy,
        'totalTimeMs': totalTimeMs,
        'avgInferenceTimeMs': avgInferenceTimeMs,
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Statistics for synthetic performance benchmarks.
class PerfStats {
  final int runs;
  final double meanMs;
  final double p50Ms;
  final double p90Ms;
  final double minMs;
  final double maxMs;

  const PerfStats({
    required this.runs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.minMs,
    required this.maxMs,
  });

  factory PerfStats.fromTimes(List<double> times) {
    if (times.isEmpty) {
      return const PerfStats(runs: 0, meanMs: 0, p50Ms: 0, p90Ms: 0, minMs: 0, maxMs: 0);
    }
    times.sort();
    return PerfStats(
      runs: times.length,
      meanMs: times.reduce((a, b) => a + b) / times.length,
      p50Ms: times[(times.length * 0.5).floor()],
      p90Ms: times[(times.length * 0.9).floor()],
      minMs: times.first,
      maxMs: times.last,
    );
  }

  double get fps => meanMs > 0 ? 1000.0 / meanMs : 0;

  Map<String, dynamic> toJson() => {
        'runs': runs,
        'meanMs': meanMs,
        'p50Ms': p50Ms,
        'p90Ms': p90Ms,
        'minMs': minMs,
        'maxMs': maxMs,
        'fps': fps,
      };
}
