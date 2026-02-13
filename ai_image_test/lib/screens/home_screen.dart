import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../engines/engine.dart';
import '../engines/histogram_engine.dart';
import '../engines/tflite_engine.dart';
import '../engines/onnx_engine.dart';
import '../engines/onnx_directml_engine.dart';
import '../engines/gpu_server_engine.dart';
import '../services/model_manager.dart';
import '../services/test_set_loader.dart';
import '../services/gpu_capability_checker.dart';
import '../models/test_image_pair.dart';
import 'benchmark_screen.dart';
import 'perf_check_screen.dart';
import 'results_screen.dart';
import 'model_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Engine selection
  String _selectedEngine = 'histogram';
  String _selectedDevice = 'CPU';
  double _threshold = 0.5;
  String _gpuServerUrl = 'http://localhost:8000';

  // Test set
  String? _testSetPath;
  List<TestImagePair>? _loadedPairs;
  bool _loading = false;
  String? _errorMessage;

  final _modelManager = ModelManager();
  final _gpuChecker = GpuCapabilityChecker.instance;

  // Available engine options
  static const _engineOptions = {
    'histogram': 'Histogram (ベースライン)',
    'tflite': 'TFLite (CPU/GPU)',
    'onnx': 'ONNX Runtime',
    'onnx_directml': 'ONNX DirectML (Windows)',
    'gpu_server': 'GPU Server (リモート)',
  };

  @override
  void initState() {
    super.initState();
    _gpuChecker.logCapabilities();
    _updateAvailableDevice();
  }

  void _updateAvailableDevice() {
    List<String> devices;
    switch (_selectedEngine) {
      case 'tflite':
        devices = TfliteEngine.availableDevices;
        break;
      case 'onnx':
        devices = OnnxEngine.availableDevices;
        break;
      case 'onnx_directml':
        devices = OnnxDirectMLEngine.availableDevices;
        break;
      default:
        devices = ['CPU'];
    }
    
    // Update selected device if current selection is not available
    if (!devices.contains(_selectedDevice)) {
      setState(() {
        _selectedDevice = devices.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'モデル管理',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModelManagementScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '過去の結果',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResultsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Engine Selection ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('推論エンジン', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._engineOptions.entries.map((e) => RadioListTile<String>(
                          title: Text(e.value),
                          value: e.key,
                          groupValue: _selectedEngine,
                          onChanged: (v) {
                            setState(() {
                              _selectedEngine = v!;
                              _updateAvailableDevice();
                            });
                          },
                          dense: true,
                        )),
                    if (_selectedEngine == 'gpu_server') ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'サーバーURL',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _gpuServerUrl = v,
                        controller: TextEditingController(text: _gpuServerUrl),
                      ),
                    ],
                    // Device selection for TFLite and ONNX
                    if (_selectedEngine == 'tflite' || 
                        _selectedEngine == 'onnx' || 
                        _selectedEngine == 'onnx_directml') ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('デバイス選択', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDevice,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '実行デバイス',
                        ),
                        items: _getAvailableDevices()
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedDevice = v!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '利用可能: ${_gpuChecker.capabilitiesDescription}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Threshold ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('類似度閾値: ${_threshold.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Slider(
                      value: _threshold,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      label: _threshold.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _threshold = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Test Set ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('テストセット', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _testSetPath ?? '未選択',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          label: const Text('フォルダ'),
                          onPressed: _pickFolder,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.archive),
                          label: const Text('ZIP'),
                          onPressed: _pickZip,
                        ),
                      ],
                    ),
                    if (_loadedPairs != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_loadedPairs!.length} ペア読み込み済み',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 24),

            // ── Action Buttons ──
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('ベンチマーク開始'),
                onPressed: _loadedPairs != null ? _startBenchmark : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.speed),
                label: const Text('パフォーマンスチェック'),
                onPressed: _startPerfCheck,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    await _loadTestSet(path, isZip: false);
  }

  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    await _loadTestSet(result.files.single.path!, isZip: true);
  }

  Future<void> _loadTestSet(String path, {required bool isZip}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final loader = TestSetLoader();
      final pairs = isZip
          ? await loader.loadFromZip(path)
          : await loader.loadFromDirectory(path);

      setState(() {
        _testSetPath = path;
        _loadedPairs = pairs;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'テストセット読み込みエラー: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> _getAvailableDevices() {
    switch (_selectedEngine) {
      case 'tflite':
        return TfliteEngine.availableDevices;
      case 'onnx':
        return OnnxEngine.availableDevices;
      case 'onnx_directml':
        return OnnxDirectMLEngine.availableDevices;
      default:
        return ['CPU'];
    }
  }

  Future<InferenceEngine> _createEngine() async {
    switch (_selectedEngine) {
      case 'tflite':
        final models = ModelManager.builtInModels;
        final recommended = models.firstWhere((m) => m.isRecommended, orElse: () => models.first);
        final modelPath = await _modelManager.getModelPath(recommended);
        if (modelPath == null) {
          throw Exception('モデルがダウンロードされていません。モデル管理画面からダウンロードしてください。');
        }
        return TfliteEngine(
          modelName: recommended.name, 
          modelPath: modelPath, 
          inputSize: recommended.inputSize,
          device: _selectedDevice,
        );
      case 'onnx':
        final models = ModelManager.builtInModels;
        final recommended = models.firstWhere((m) => m.isRecommended, orElse: () => models.first);
        final modelPath = await _modelManager.getModelPath(recommended, preferOnnx: true);
        if (modelPath == null) {
          throw Exception('モデルがダウンロードされていません。モデル管理画面からダウンロードしてください。');
        }
        return OnnxEngine(
          modelName: recommended.name, 
          modelPath: modelPath, 
          inputSize: recommended.inputSize,
          device: _selectedDevice,
        );
      case 'onnx_directml':
        final models = ModelManager.builtInModels;
        final recommended = models.firstWhere((m) => m.isRecommended, orElse: () => models.first);
        final modelPath = await _modelManager.getModelPath(recommended, preferOnnx: true);
        if (modelPath == null) {
          throw Exception('モデルがダウンロードされていません。モデル管理画面からダウンロードしてください。');
        }
        return OnnxDirectMLEngine(
          modelName: recommended.name, 
          modelPath: modelPath, 
          inputSize: recommended.inputSize,
          device: _selectedDevice,
        );
      case 'gpu_server':
        return GpuServerEngine(serverUrl: _gpuServerUrl);
      case 'histogram':
      default:
        return HistogramEngine();
    }
  }

  Future<void> _startBenchmark() async {
    if (_loadedPairs == null || _loadedPairs!.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final engine = await _createEngine();
      await engine.initialize();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BenchmarkScreen(
            engine: engine,
            pairs: _loadedPairs!,
            threshold: _threshold,
            testSetName: _testSetPath ?? 'unknown',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'エンジン初期化エラー: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startPerfCheck() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final engine = await _createEngine();
      await engine.initialize();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PerfCheckScreen(engine: engine),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'エンジン初期化エラー: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }
}
