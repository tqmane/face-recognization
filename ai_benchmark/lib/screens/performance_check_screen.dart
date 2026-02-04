import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engines/tflite_engine.dart';
import '../services/model_manager.dart';
import '../services/native_lib_checker.dart';
import '../services/performance_benchmark.dart';

class PerformanceCheckScreen extends StatefulWidget {
  const PerformanceCheckScreen({super.key});

  @override
  State<PerformanceCheckScreen> createState() => _PerformanceCheckScreenState();
}

class _PerformanceCheckScreenState extends State<PerformanceCheckScreen> {
  bool _loading = true;
  List<ModelItem> _downloadedModels = [];
  String? _selectedModelKey;
  String _selectedDevice = 'CPU';
  int _threads = 0; // 0 = auto

  bool _running = false;
  String _status = '';
  final Map<String, BenchmarkStats> _results = {};

  late final NativeLibStatus _tfliteCpuLibStatus = checkTfliteCpuNativeLibrary();

  int get _autoThreads => Platform.numberOfProcessors <= 0 ? 4 : Platform.numberOfProcessors;

  @override
  void initState() {
    super.initState();
    _threads = 0;
    _loadModels();
  }

  Future<void> _loadModels() async {
    final manager = ModelManager();
    final models = await manager.listModels();
    final downloaded = <ModelItem>[];
    for (final m in models) {
      if (await manager.isModelDownloaded(m.key)) {
        downloaded.add(m);
      }
    }

    if (!mounted) return;
    setState(() {
      _downloadedModels = downloaded;
      _selectedModelKey = downloaded.isNotEmpty ? downloaded.first.key : null;
      _loading = false;
    });
  }

  Future<void> _runOnce({required String device, required int threads}) async {
    final key = _selectedModelKey;
    if (key == null) return;

    setState(() {
      _running = true;
      _status = '計測中: $device / threads=$threads';
    });

    try {
      final manager = ModelManager();
      final model = _downloadedModels.firstWhere((m) => m.key == key);
      final file = await manager.getModelFile(model.key);

      final engine = TfliteEngine(
        modelName: model.name,
        modelPath: file.path,
        inputSize: model.inputSize,
        device: device,
        threads: threads,
      );

      await engine.initialize();
      final stats = await engine.runSyntheticBenchmark(warmupRuns: 30, runs: 200);
      engine.dispose();

      if (!mounted) return;
      setState(() {
        _results['$device/$threads'] = stats;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results['$device/$threads'] = const BenchmarkStats(
          runs: 0,
          meanMs: 0,
          p50Ms: 0,
          p90Ms: 0,
          minMs: 0,
          maxMs: 0,
        );
        _status = '失敗: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _status = _status.isEmpty ? '完了' : _status;
        });
      }
    }
  }

  Future<void> _runSelected() async {
    final threads = _threads == 0 ? _autoThreads : _threads;
    await _runOnce(device: _selectedDevice, threads: threads);
  }

  Future<void> _runMaxPerformanceSuite() async {
    // CPU: 1-thread + auto threads; GPU: auto threads (if selected device supports it, user can pick).
    final auto = _autoThreads;
    await _runOnce(device: 'CPU', threads: 1);
    await _runOnce(device: 'CPU', threads: auto);

    if (Platform.isAndroid || Platform.isIOS) {
      await _runOnce(device: 'GPU', threads: auto);
    }
  }

  Widget _resultTile(String key, BenchmarkStats stats) {
    return ListTile(
      dense: true,
      title: Text(key),
      subtitle: Text(
        'mean ${formatMs(stats.meanMs)}ms / p50 ${formatMs(stats.p50Ms)}ms / p90 ${formatMs(stats.p90Ms)}ms  (fps ~ ${stats.fps.toStringAsFixed(1)})',
      ),
      trailing: Text('${stats.runs} runs'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final desktopTfliteBlocked =
        !(_tfliteCpuLibStatus.available) && !(Platform.isAndroid || Platform.isIOS);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('性能チェック'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最大性能で測るための推奨状態', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('・充電中（AC接続）\n・省電力/バッテリーセーバーOFF\n・端末を冷やす（熱で性能が落ちます）\n・他アプリ終了\n・同条件で複数回測る'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('端末情報', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('OS: ${Platform.operatingSystem}  / CPU cores: ${Platform.numberOfProcessors}'),
                  const SizedBox(height: 8),
                  Text('注意: この計測は「合成入力」で純粋な推論レイテンシを測ります（I/Oや画像前処理は含みません）。', style: TextStyle(color: cs.onSurface.withAlpha((0.7 * 255).round()))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (desktopTfliteBlocked)
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'デスクトップTFLiteが未設定',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tfliteCpuLibStatus.message,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '期待パス: ${_tfliteCpuLibStatus.expectedPath}',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_downloadedModels.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('計測にはTFLiteモデルのダウンロードが必要です。ホーム画面の設定からモデルを取得してください。'),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('計測設定', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'モデル', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedModelKey,
                          items: _downloadedModels
                              .map((m) => DropdownMenuItem(value: m.key, child: Text(m.name)))
                              .toList(),
                          onChanged: _running ? null : (v) => setState(() => _selectedModelKey = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'デバイス', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedDevice,
                          items: <String>['CPU', if (Platform.isAndroid || Platform.isIOS) 'GPU']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: _running ? null : (v) => setState(() => _selectedDevice = v ?? 'CPU'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('スレッド数: ${_threads == 0 ? 'AUTO($_autoThreads)' : _threads}'),
                    Slider(
                      value: _threads.toDouble(),
                      min: 0,
                      max: math.max(1, _autoThreads).toDouble(),
                      divisions: math.max(1, _autoThreads),
                      label: _threads == 0 ? 'AUTO' : '$_threads',
                      onChanged: _running
                          ? null
                          : (v) => setState(() => _threads = v.round().clamp(0, _autoThreads)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: (_running || desktopTfliteBlocked) ? null : _runSelected,
                            icon: const Icon(Icons.speed),
                            label: const Text('この条件で計測'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_running || desktopTfliteBlocked) ? null : _runMaxPerformanceSuite,
                            icon: const Icon(Icons.auto_graph),
                            label: const Text('CPU/GPU一括'),
                          ),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_results.isNotEmpty)
            Card(
              child: Column(
                children: [
                  const ListTile(title: Text('結果')),
                  const Divider(height: 1),
                  ..._results.entries.map((e) => _resultTile(e.key, e.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
