import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../engines/engine.dart';
import '../models/test_image_pair.dart';
import '../models/inference_result.dart';
import '../models/benchmark_run.dart';
import '../services/result_exporter.dart';

/// Runs the benchmark: iterates through pairs, measures accuracy and latency.
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({
    super.key,
    required this.engine,
    required this.pairs,
    required this.threshold,
    required this.testSetName,
  });

  final InferenceEngine engine;
  final List<TestImagePair> pairs;
  final double threshold;
  final String testSetName;

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  int _current = 0;
  bool _running = false;
  bool _complete = false;
  final _results = <InferenceResult>[];
  final _stopwatch = Stopwatch();
  BenchmarkRun? _run;

  @override
  void initState() {
    super.initState();
    _startBenchmark();
  }

  @override
  void dispose() {
    widget.engine.dispose();
    super.dispose();
  }

  Future<void> _startBenchmark() async {
    setState(() {
      _running = true;
      _current = 0;
      _results.clear();
    });

    _stopwatch.reset();
    _stopwatch.start();

    for (int i = 0; i < widget.pairs.length; i++) {
      if (!mounted || !_running) break;
      final pair = widget.pairs[i];

      try {
        final sw = Stopwatch()..start();
        final similarity = await widget.engine.compareImages(
          pair.imagePath1,
          pair.imagePath2,
        );
        sw.stop();
        final elapsedMs = sw.elapsedMicroseconds / 1000.0;

        final predicted = similarity >= widget.threshold;
        _results.add(InferenceResult(
          questionId: pair.id,
          genre: pair.genre,
          imagePath1: pair.imagePath1,
          imagePath2: pair.imagePath2,
          actualMatch: pair.isSame,
          predictedMatch: predicted,
          similarityScore: similarity,
          inferenceTimeMs: elapsedMs,
        ));
      } catch (e) {
        _results.add(InferenceResult(
          questionId: pair.id,
          genre: pair.genre,
          imagePath1: pair.imagePath1,
          imagePath2: pair.imagePath2,
          actualMatch: pair.isSame,
          predictedMatch: false,
          similarityScore: -1.0,
          inferenceTimeMs: 0,
        ));
      }

      setState(() => _current = i + 1);
    }

    _stopwatch.stop();

    final correctCount = _results.where((r) => r.isCorrect).length;
    _run = BenchmarkRun(
      runId: 'run_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      engineName: widget.engine.name,
      device: widget.engine.name,
      threads: 1,
      testSetName: p.basename(widget.testSetName),
      threshold: widget.threshold,
      totalQuestions: _results.length,
      correctCount: correctCount,
      accuracy: _results.isEmpty ? 0 : correctCount / _results.length,
      totalTimeMs: _stopwatch.elapsedMilliseconds,
      avgInferenceTimeMs: _results.isEmpty
          ? 0
          : _results.map((r) => r.inferenceTimeMs).reduce((a, b) => a + b) /
              _results.length,
      results: _results,
    );

    setState(() {
      _running = false;
      _complete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.pairs.isEmpty ? 0.0 : _current / widget.pairs.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_complete ? 'ベンチマーク結果' : 'ベンチマーク実行中'),
        leading: _running
            ? IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () => setState(() => _running = false),
              )
            : null,
      ),
      body: _complete ? _buildResults() : _buildProgress(progress),
    );
  }

  Widget _buildProgress(double progress) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 24),
            Text(
              '$_current / ${widget.pairs.length}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('エンジン: ${widget.engine.name}'),
            if (_current > 0)
              Text(
                '経過時間: ${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_run == null) return const Center(child: Text('データなし'));

    final run = _run!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary card
          Card(
            color: run.accuracy >= 0.7
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '正解率: ${(run.accuracy * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('${run.correctCount} / ${run.totalQuestions} 正解'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Stats card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow('エンジン', run.engineName),
                  _statRow('テストセット', run.testSetName),
                  _statRow('閾値', run.threshold.toStringAsFixed(2)),
                  _statRow('合計時間', '${run.totalTimeMs}ms'),
                  _statRow('平均推論時間', '${run.avgInferenceTimeMs.toStringAsFixed(1)}ms'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Export buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('JSON保存'),
                  onPressed: () => _export('json'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('CSV保存'),
                  onPressed: () => _export('csv'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('共有'),
                  onPressed: () => _export('share'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Per-question results
          Text('個別結果', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: run.results.length,
            itemBuilder: (_, i) {
              final r = run.results[i];
              return ListTile(
                leading: Icon(
                  r.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: r.isCorrect ? Colors.green : Colors.red,
                ),
                title: Text('Q${r.questionId} – ${r.genre}'),
                subtitle: Text(
                  '類似度 ${r.similarityScore.toStringAsFixed(3)} '
                  '(${r.inferenceTimeMs.toStringAsFixed(1)}ms) '
                  '実際: ${r.actualMatch ? "同種" : "異種"} → '
                  '予測: ${r.predictedMatch ? "同種" : "異種"}',
                ),
                dense: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _export(String type) async {
    if (_run == null) return;
    final exporter = ResultExporter();
    try {
      switch (type) {
        case 'json':
          final file = await exporter.exportJson(_run!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存しました: ${file.path}')),
          );
          break;
        case 'csv':
          final file = await exporter.exportDetailCsv(_run!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存しました: ${file.path}')),
          );
          break;
        case 'share':
          final file = await exporter.exportJson(_run!);
          await exporter.shareFile(file);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートエラー: $e')),
      );
    }
  }
}
