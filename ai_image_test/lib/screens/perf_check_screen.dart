import 'package:flutter/material.dart';
import '../engines/engine.dart';
import '../models/benchmark_run.dart';

/// Runs a synthetic performance check (no test images needed).
class PerfCheckScreen extends StatefulWidget {
  const PerfCheckScreen({super.key, required this.engine});

  final InferenceEngine engine;

  @override
  State<PerfCheckScreen> createState() => _PerfCheckScreenState();
}

class _PerfCheckScreenState extends State<PerfCheckScreen> {
  bool _running = false;
  PerfStats? _stats;
  String? _error;
  int _iterations = 100;

  @override
  void dispose() {
    widget.engine.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _stats = null;
    });

    try {
      final stats = await widget.engine.runSyntheticBenchmark(runs: _iterations);
      setState(() => _stats = stats);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パフォーマンスチェック')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('エンジン: ${widget.engine.name}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('反復回数: '),
                        DropdownButton<int>(
                          value: _iterations,
                          items: [50, 100, 200, 500, 1000]
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                              .toList(),
                          onChanged: _running
                              ? null
                              : (v) => setState(() => _iterations = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.speed),
                      label: Text(_running ? '実行中...' : 'テスト開始'),
                      onPressed: _running ? null : _run,
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),

            if (_stats != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('結果', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _row('実行回数', '${_stats!.runs}'),
                      _row('平均', '${_stats!.meanMs.toStringAsFixed(2)} ms'),
                      _row('中央値 (P50)', '${_stats!.p50Ms.toStringAsFixed(2)} ms'),
                      _row('P90', '${_stats!.p90Ms.toStringAsFixed(2)} ms'),
                      _row('最小', '${_stats!.minMs.toStringAsFixed(2)} ms'),
                      _row('最大', '${_stats!.maxMs.toStringAsFixed(2)} ms'),
                      _row('FPS', '${_stats!.fps.toStringAsFixed(1)}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Visual bar chart
              if (_stats!.runs > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('レイテンシ分布',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildBar('Mean', _stats!.meanMs, Colors.blue),
                        _buildBar('P50', _stats!.p50Ms, Colors.green),
                        _buildBar('P90', _stats!.p90Ms, Colors.orange),
                        _buildBar('Max', _stats!.maxMs, Colors.red),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double ms, Color color) {
    final maxMs = _stats!.maxMs;
    final fraction = maxMs > 0 ? (ms / maxMs).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 16,
              color: color,
              backgroundColor: color.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text('${ms.toStringAsFixed(1)}ms',
                style: const TextStyle(fontSize: 12), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
