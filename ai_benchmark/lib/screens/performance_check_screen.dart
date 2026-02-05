import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engines/tflite_engine.dart';
import '../engines/onnx_engine.dart';
import '../engines/gpu_server_engine.dart';
import '../engines/inference_engine.dart';
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
  ModelFormat _currentModelFormat = ModelFormat.tflite;
  bool _useGpuServer = false;
  bool _gpuServerAvailable = false;

  bool _running = false;
  String _status = '';
  final Map<String, BenchmarkStats> _results = {};

  late final NativeLibStatus _tfliteCpuLibStatus = checkTfliteCpuNativeLibrary();

  int get _autoThreads => Platform.numberOfProcessors <= 0 ? 4 : Platform.numberOfProcessors;

  /// Get available devices based on current model format and GPU server
  List<String> get _availableDevices {
    if (_useGpuServer) {
      return ['GPU Server'];
    } else if (_currentModelFormat == ModelFormat.onnx) {
      return OnnxEngine.availableDevices;
    } else {
      return TfliteEngine.availableDevices;
    }
  }

  /// Check if GPU is available for current format
  bool get _isGpuAvailable {
    if (_useGpuServer) return true;
    if (_currentModelFormat == ModelFormat.onnx) {
      return OnnxEngine.isGpuAvailable;
    } else {
      return TfliteEngine.isGpuAvailable;
    }
  }

  @override
  void initState() {
    super.initState();
    _threads = 0;
    _loadModels();
    _checkGpuServer();
  }

  Future<void> _checkGpuServer() async {
    final available = await GpuServerEngine.isServerRunning();
    if (mounted) {
      setState(() {
        _gpuServerAvailable = available;
      });
    }
  }

  Future<void> _loadModels() async {
    final manager = ModelManager();
    final models = await manager.listModels();
    final downloaded = <ModelItem>[];
    for (final m in models) {
      // Check if any format is downloaded
      final result = await manager.getBestModelFile(m.key);
      if (result != null) {
        downloaded.add(m);
      }
    }

    if (!mounted) return;
    setState(() {
      _downloadedModels = downloaded;
      _selectedModelKey = downloaded.isNotEmpty ? downloaded.first.key : null;
      _updateModelFormat();
      _loading = false;
    });
  }

  Future<void> _updateModelFormat() async {
    if (_selectedModelKey == null) return;
    
    final manager = ModelManager();
    final result = await manager.getBestModelFile(_selectedModelKey!);
    if (result != null && mounted) {
      setState(() {
        _currentModelFormat = result.$2;
        // Reset device if current selection isn't available
        if (!_availableDevices.contains(_selectedDevice)) {
          _selectedDevice = 'CPU';
        }
      });
    }
  }

  Future<void> _runOnce({required String device, required int threads}) async {
    final key = _selectedModelKey;
    if (key == null) return;

    setState(() {
      _running = true;
      _status = _useGpuServer 
          ? '計測中: GPU Server' 
          : '計測中: $device / threads=$threads (${_currentModelFormat.name})';
    });

    try {
      final manager = ModelManager();
      final model = _downloadedModels.firstWhere((m) => m.key == key);
      
      InferenceEngine engine;
      
      if (_useGpuServer) {
        // GPU Server モード: ONNXモデルが必要
        final onnxFile = await manager.getModelFile(model.key, format: ModelFormat.onnx);
        engine = GpuServerEngine(
          modelName: model.name,
          modelPath: onnxFile.path,
          inputSize: model.inputSize,
        );
      } else {
        final result = await manager.getBestModelFile(model.key);
        
        if (result == null) {
          throw Exception('モデルファイルが見つかりません');
        }
        
        final (file, format) = result;

        if (format == ModelFormat.onnx) {
          engine = OnnxEngine(
            modelName: model.name,
            modelPath: file.path,
            inputSize: model.inputSize,
            device: device,
            threads: threads,
          );
        } else {
          engine = TfliteEngine(
            modelName: model.name,
            modelPath: file.path,
            inputSize: model.inputSize,
            device: device,
            threads: threads,
          );
        }
      }

      await engine.initialize();
      final stats = await engine.runSyntheticBenchmark(warmupRuns: 30, runs: 200);
      engine.dispose();

      if (!mounted) return;
      setState(() {
        final label = _useGpuServer ? 'GPU Server' : '$device/$threads (${_currentModelFormat.name})';
        _results[label] = stats;
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
    // CPU: 1-thread + auto threads; GPU: auto threads (if available on platform)
    final auto = _autoThreads;
    await _runOnce(device: 'CPU', threads: 1);
    await _runOnce(device: 'CPU', threads: auto);

    if (_isGpuAvailable && _availableDevices.length > 1) {
      // Use the first GPU device available
      final gpuDevice = _availableDevices.firstWhere((d) => d != 'CPU', orElse: () => 'GPU');
      await _runOnce(device: gpuDevice, threads: auto);
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
    // TFLite blocked only matters if we're using TFLite format on desktop
    final isDesktop = !(Platform.isAndroid || Platform.isIOS);
    final desktopTfliteBlocked = isDesktop && 
        !(_tfliteCpuLibStatus.available) && 
        _currentModelFormat == ModelFormat.tflite;

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
                    // GPU Server Toggle (Windows/Linux only)
                    if (Platform.isWindows || Platform.isLinux)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _gpuServerAvailable 
                              ? cs.primaryContainer 
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _gpuServerAvailable ? Icons.check_circle : Icons.info_outline,
                              color: _gpuServerAvailable ? cs.primary : cs.onSurface.withAlpha(150),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GPU Server モード',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _gpuServerAvailable 
                                        ? 'サーバー接続中 (127.0.0.1:8765)' 
                                        : 'サーバー未起動 - ドキュメント参照',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: cs.onSurface.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _useGpuServer,
                              onChanged: (_running || !_gpuServerAvailable) 
                                  ? null 
                                  : (v) => setState(() => _useGpuServer = v),
                            ),
                          ],
                        ),
                      ),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'モデル', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedModelKey,
                          items: _downloadedModels
                              .map((m) => DropdownMenuItem(value: m.key, child: Text('${m.name} (${_currentModelFormat.name})')))
                              .toList(),
                          onChanged: _running ? null : (v) {
                            setState(() => _selectedModelKey = v);
                            _updateModelFormat();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // GPU Serverモード時はデバイス・スレッド設定を非表示
                    if (!_useGpuServer) ...[
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'デバイス', border: OutlineInputBorder()),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDevice,
                            items: _availableDevices
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: _running ? null : (v) => setState(() => _selectedDevice = v ?? 'CPU'),
                          ),
                        ),
                      ),
                      if (!_isGpuAvailable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '※ ${Platform.operatingSystem}ではGPUアクセラレーションは利用できません',
                            style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha((0.6 * 255).round())),
                          ),
                        ),
                      if (_currentModelFormat == ModelFormat.onnx)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '✓ ONNXモデル使用中 (GPU対応)',
                            style: TextStyle(fontSize: 12, color: cs.primary),
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
                    ] else ...[
                      // GPU Serverモード時の情報表示
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚀 GPU Server 推論モード',
                              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'サーバーが自動的に最適なGPUプロバイダーを選択します\n'
                              '(DirectML / CUDA / CPU)',
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(180)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: (_running || desktopTfliteBlocked) ? null : _runSelected,
                            icon: const Icon(Icons.speed),
                            label: Text(_useGpuServer ? 'GPU Serverで計測' : 'この条件で計測'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            // GPU Serverモード時は一括計測を無効化
                            onPressed: (_running || desktopTfliteBlocked || _useGpuServer) 
                                ? null 
                                : _runMaxPerformanceSuite,
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
