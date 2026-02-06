import '../models/benchmark_run.dart';

/// Abstract interface for all image-comparison engines.
abstract class InferenceEngine {
  String get name;

  /// Initialise the engine (load model, allocate resources).
  Future<void> initialize();

  /// Compare two images and return a similarity score in [0, 1].
  Future<double> compareImages(String imagePath1, String imagePath2);

  /// Run a synthetic (dummy-input) benchmark and return latency stats.
  Future<PerfStats> runSyntheticBenchmark({
    int warmupRuns = 30,
    int runs = 200,
  });

  /// Release resources.
  void dispose();
}
