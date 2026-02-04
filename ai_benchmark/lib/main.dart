import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import 'engines/inference_engine.dart';
import 'engines/histogram_engine.dart';
import 'engines/tflite_engine.dart';
import 'services/test_set_loader.dart';
import 'services/hardware_checker.dart';
import 'services/model_manager.dart';
import 'models/quiz_question.dart';

void main() {
  runApp(const AiBenchmarkApp());
}

class AiBenchmarkApp extends StatelessWidget {
  const AiBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Benchmark',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const BenchmarkHomeScreen(),
    );
  }
}

class BenchmarkHomeScreen extends StatefulWidget {
  const BenchmarkHomeScreen({super.key});

  @override
  State<BenchmarkHomeScreen> createState() => _BenchmarkHomeScreenState();
}

class _BenchmarkHomeScreenState extends State<BenchmarkHomeScreen> {
  static const String kHistogramModelName = 'Color Histogram';

  String _selectedModelKey = kHistogramModelName;
  String _selectedDevice = 'CPU';
  String? _testSetPath;
  bool _isRunning = false;
  double _progress = 0.0;
  String _statusMessage = 'Checking hardware...';
  double _similarityThreshold = 0.85;

  // Hardware status
  List<String> _availableDevices = ['CPU'];

  // Models status - individual download tracking
  Map<String, bool> _modelsDownloaded = {};
  final Map<String, double> _downloadProgress = {};
  bool _isLoadingModels = true;
  List<ModelItem> _models = [];
  Set<String> _customModelKeys = {};

  // Stats
  int _totalImages = 0;
  int _processedImages = 0;
  double _currentAccuracy = 0.0;
  int _elapsedTimeMs = 0;
  List<InferenceResult> _results = [];

  @override
  void initState() {
    super.initState();
    _checkSystem();
  }

  Future<void> _checkSystem() async {
    // Initialize model download status
    final manager = ModelManager();
    final downloadedStatus = <String, bool>{};
    final customModels = await manager.listCustomModels();
    final allModels = await manager.listModels();
    for (final model in allModels) {
      downloadedStatus[model.key] = await manager.isModelDownloaded(model.key);
    }

    if (!mounted) return;

    setState(() {
      _modelsDownloaded = downloadedStatus;
      _models = allModels;
      _customModelKeys = customModels.map((m) => m.key).toSet();
      _isLoadingModels = false;
    });

    final hasAnyDownloadedModel = _modelsDownloaded.values.any((downloaded) => downloaded);

    // Hardware Check (only meaningful when a TFLite model exists)
    if (hasAnyDownloadedModel) {
      final checker = HardwareChecker();
      final firstModelKey = _modelsDownloaded.entries.firstWhere((e) => e.value).key;
      final modelFile = await manager.getModelFile(firstModelKey);
      final status = await checker.checkAvailability(modelFile.path);

      if (!mounted) return;

      setState(() {
        _availableDevices = status.entries.where((e) => e.value).map((e) => e.key).toList();

        if (_availableDevices.contains('GPU')) {
          _selectedDevice = 'GPU';
        } else if (_availableDevices.contains('NNAPI')) {
          _selectedDevice = 'NNAPI';
        } else {
          _selectedDevice = 'CPU';
        }

        _statusMessage = '準備完了: ${_availableDevices.join(", ")}';
      });
    } else {
      if (!mounted) return;
      setState(() {
        _availableDevices = ['CPU'];
        _selectedDevice = 'CPU';
        _statusMessage = 'モデル未ダウンロード: Histogramで実行するか、設定からモデルを取得してください';
      });
    }

    // Prefer recommended downloaded model; otherwise keep Histogram.
    final downloadedModels = _models.where((m) => _modelsDownloaded[m.key] == true).toList();
    if (downloadedModels.isNotEmpty && mounted) {
      final preferred = downloadedModels.firstWhere(
        (m) => m.isRecommended,
        orElse: () => downloadedModels.first,
      );
      setState(() {
        if (_selectedModelKey == kHistogramModelName) {
          _selectedModelKey = preferred.name;
        }
      });
    }

    // Ensure selection is valid.
    final selectableNames = <String>{
      kHistogramModelName,
      ...downloadedModels.map((m) => m.name),
    };
    if (!selectableNames.contains(_selectedModelKey) && mounted) {
      setState(() => _selectedModelKey = kHistogramModelName);
    }
  }

  Future<void> _downloadModel(ModelItem model) async {
    final manager = ModelManager();

    setState(() {
      _downloadProgress[model.key] = 0.0;
    });

    try {
      await manager.downloadModel(model.key, (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[model.key] = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _modelsDownloaded[model.key] = true;
          _downloadProgress.remove(model.key);
        });
        await _checkSystem();

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} をダウンロードしました'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(model.key);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ダウンロードエラー: $e'),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    }
  }

  Future<void> _deleteModel(ModelItem model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${model.name} を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final manager = ModelManager();
      final file = await manager.getModelFile(model.key);
      if (await file.exists()) {
        await file.delete();
      }

      if (_customModelKeys.contains(model.key)) {
        await manager.removeCustomModel(model.key);
      }

      setState(() {
        _modelsDownloaded[model.key] = false;
        if (_selectedModelKey == model.name) {
          _selectedModelKey = kHistogramModelName;
        }
      });
      await _checkSystem();
      if (mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} を削除しました'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Future<void> _addModelFromUrl() async {
    final manager = ModelManager();
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final inputSizeCtrl = TextEditingController(text: '224');
    final fileNameCtrl = TextEditingController();

    final added = await showDialog<ModelItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URLからモデル追加'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '表示名'),
              ),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'URL (.tflite / .tgz / .tar.gz)'),
              ),
              TextField(
                controller: inputSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '入力サイズ (例: 224)'),
              ),
              TextField(
                controller: fileNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'アーカイブ内の .tflite 名 (必要な場合)',
                  helperText: 'URLが .tflite 直リンクなら空でOK',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final inputSize = int.tryParse(inputSizeCtrl.text.trim()) ?? 224;
              final uri = Uri.tryParse(url);
              if (name.isEmpty || uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
                return;
              }

              final urlPath = uri.path.toLowerCase();
              final isDirectTflite = urlPath.endsWith('.tflite');
              final fileNameInArchive = fileNameCtrl.text.trim().isNotEmpty
                  ? fileNameCtrl.text.trim()
                  : (isDirectTflite ? p.basename(uri.path) : '');
              if (fileNameInArchive.isEmpty) {
                return;
              }

              final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
              Navigator.pop(
                context,
                ModelItem(
                  key: key,
                  name: name,
                  url: url,
                  fileNameInArchive: fileNameInArchive,
                  inputSize: inputSize,
                ),
              );
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (added == null) return;
    await manager.addCustomModel(added);
    await _checkSystem();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('追加しました: ${added.name}')),
    );
  }

  Future<void> _importLocalModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tflite'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: p.basenameWithoutExtension(path));
    final inputSizeCtrl = TextEditingController(text: '224');

    final meta = await showDialog<ModelItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ローカルモデル取り込み'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ファイル: ${p.basename(path)}'),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '表示名'),
              ),
              TextField(
                controller: inputSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '入力サイズ (例: 224)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final inputSize = int.tryParse(inputSizeCtrl.text.trim()) ?? 224;
              if (name.isEmpty) return;
              final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
              Navigator.pop(
                context,
                ModelItem(
                  key: key,
                  name: name,
                  url: null,
                  fileNameInArchive: p.basename(path),
                  inputSize: inputSize,
                ),
              );
            },
            child: const Text('取り込み'),
          ),
        ],
      ),
    );

    if (meta == null) return;
    final manager = ModelManager();
    await manager.importLocalModel(localTflitePath: path, meta: meta);
    await _checkSystem();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('取り込みました: ${meta.name}')),
    );
  }

  Future<void> _pickTestSet() async {
    // Storage permissions are Android-specific. iOS and desktop use sandbox pickers.
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
    if (!mounted) return;

    String? path;

    // Desktop: let user choose ZIP or folder explicitly.
    if (!Platform.isAndroid && !Platform.isIOS) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('テストセットの形式'),
          content: const Text('ZIPファイルかフォルダを選択してください'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'dir'),
              child: const Text('フォルダ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'zip'),
              child: const Text('ZIP'),
            ),
          ],
        ),
      );

      if (choice == 'dir') {
        path = await FilePicker.platform.getDirectoryPath();
      } else if (choice == 'zip') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
        path = result?.files.single.path;
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      path = result?.files.single.path;
    }

    if (path != null) {
      setState(() {
        _testSetPath = path;
        _statusMessage = '選択中: ${p.basename(path!)}';
      });
    }
  }

  Future<InferenceEngine?> _createEngine(String key, String device) async {
    if (key == kHistogramModelName) {
      return HistogramEngine();
    }

    final modelInfo = _models.firstWhere(
      (m) => m.name == key,
      orElse: () => _models.first,
    );

    final manager = ModelManager();
    final file = await manager.getModelFile(modelInfo.key);

    if (!await file.exists()) {
      setState(() => _statusMessage = 'モデルが見つかりません: ${file.path}');
      return null;
    }

    return TfliteEngine(
      modelName: modelInfo.name,
      modelPath: file.path,
      inputSize: modelInfo.inputSize,
      device: device,
    );
  }

  Future<void> _runBenchmark() async {
    if (_testSetPath == null) return;

    final engine = await _createEngine(_selectedModelKey, _selectedDevice);
    if (engine == null) return;

    setState(() {
      _isRunning = true;
      _progress = 0.0;
      _processedImages = 0;
      _results = [];
      _statusMessage = '${engine.name} を初期化中...';
    });

    try {
      try {
        await engine.initialize();
      } catch (e) {
        // Desktop環境などでTFLiteが利用できない場合でも「何もできない」状態を避ける。
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('初期化に失敗: $e')),
          );
        }

        if (_selectedModelKey != kHistogramModelName && mounted) {
          setState(() {
            _selectedModelKey = kHistogramModelName;
            _statusMessage = 'TFLiteが利用できないためHistogramへフォールバックします';
          });
        }
        return;
      }

      setState(() => _statusMessage = 'テストセットを読み込み中...');
      final loader = TestSetLoader();
      List<QuizQuestion> questions;

      if (_testSetPath!.endsWith('.zip')) {
        questions = await loader.loadFromZip(_testSetPath!);
      } else {
        questions = await loader.loadFromDirectory(_testSetPath!);
      }

      _totalImages = questions.length;

      int correctCount = 0;
      final stopwatch = Stopwatch()..start();
      final threshold = _similarityThreshold;

      for (int i = 0; i < questions.length; i++) {
        if (!mounted) break;

        final q = questions[i];
        final start = DateTime.now();

        double similarity = 0.0;
        try {
          similarity = await engine.compareImages(q.image1Url, q.image2Url);
        } catch (e) {
          debugPrint('Inference error at index $i: $e');
        }

        final elapsed = DateTime.now().difference(start).inMilliseconds;

        bool predictedSame = similarity > threshold;
        bool isCorrect = (predictedSame == q.isMatch);
        if (isCorrect) correctCount++;

        _results.add(InferenceResult(
          questionId: i + 1,
          genre: q.genre,
          isSameActual: q.isMatch,
          isSamePredicted: predictedSame,
          similarityScore: similarity,
          inferenceTimeMs: elapsed,
          imagePath1: q.image1Url,
          imagePath2: q.image2Url,
        ));

        setState(() {
          _processedImages = i + 1;
          _progress = _processedImages / _totalImages;
          _currentAccuracy = correctCount / _processedImages;
          _elapsedTimeMs = stopwatch.elapsedMilliseconds;
          _statusMessage = '処理中 ${i+1}/$_totalImages...';
        });

        await Future.delayed(Duration.zero);
      }

      stopwatch.stop();
      await _exportResults();

      setState(() {
        _statusMessage = '完了！精度: ${(_currentAccuracy * 100).toStringAsFixed(1)}%';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
      });
      debugPrint('$e');
    } finally {
      engine.dispose();
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _exportResults() async {
    final dir = await getApplicationDocumentsDirectory();

    final safeModelName = _selectedModelKey
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    final safeTestSet = (_testSetPath == null)
        ? 'no_testset'
        : p.basename(_testSetPath!)
            .replaceAll(' ', '_')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]+'), '_');

    final runId = DateTime.now().millisecondsSinceEpoch;
    final prefix = 'benchmark_${safeTestSet}_${safeModelName}_$runId';

    // 1) CSV
    List<List<dynamic>> rows = [];
    rows.add([
      'Question ID',
      'Genre',
      'Image1',
      'Image2',
      'Actual Match',
      'Predicted Match',
      'Correct',
      'Similarity Score',
      'Time (ms)',
      'Model',
      'Device',
      'Threshold',
    ]);

    for (var r in _results) {
      rows.add([
        r.questionId,
        r.genre,
        r.imagePath1,
        r.imagePath2,
        r.isSameActual,
        r.isSamePredicted,
        r.isSameActual == r.isSamePredicted,
        r.similarityScore,
        r.inferenceTimeMs,
        _selectedModelKey,
        _selectedDevice,
        _similarityThreshold,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final csvFile = File('${dir.path}/$prefix.csv');
    await csvFile.writeAsString(csvData);

    // 2) JSONL (1行=1問)
    final jsonlFile = File('${dir.path}/$prefix.jsonl');
    final sink = jsonlFile.openWrite();
    for (final r in _results) {
      sink.writeln(jsonEncode({
        ...r.toJson(),
        'model': _selectedModelKey,
        'device': _selectedDevice,
        'threshold': _similarityThreshold,
      }));
    }
    await sink.flush();
    await sink.close();

    // 3) サマリJSON (run-level metadata)
    final summaryFile = File('${dir.path}/$prefix.summary.json');
    final summary = {
      'runId': runId,
      'timestamp': DateTime.now().toIso8601String(),
      'testSetPath': _testSetPath,
      'model': _selectedModelKey,
      'device': _selectedDevice,
      'threshold': _similarityThreshold,
      'total': _totalImages,
      'processed': _processedImages,
      'accuracy': _currentAccuracy,
      'elapsedTimeMs': _elapsedTimeMs,
    };
    await summaryFile.writeAsString(const JsonEncoder.withIndent('  ').convert(summary));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存しました: ${csvFile.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingModels) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final downloadedModels = _models.where((m) => _modelsDownloaded[m.key] == true).toList();
    final selectableModels = <String>[
      kHistogramModelName,
      ...downloadedModels.map((m) => m.name),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 設定ボタン（左上）
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'モデル管理',
                onPressed: () => _showModelManagement(),
              ),
            ),
            // メインコンテンツ
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // アイコン
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Text(
                            '🤖',
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // タイトル
                      Text(
                        'AI Benchmark',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AIモデルの性能を測定',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // モデル・デバイス選択カード
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '⚙️ エンジン設定',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right, color: colorScheme.onSurface.withAlpha((0.4 * 255).round())),
                                ],
                              ),
                              const SizedBox(height: 16),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'モデル',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedModelKey,
                                    items: selectableModels
                                        .map((name) => DropdownMenuItem(
                                              value: name,
                                              child: Text(name),
                                            ))
                                        .toList(),
                                    onChanged: _isRunning ? null : (v) => setState(() => _selectedModelKey = v ?? _selectedModelKey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'デバイス',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedDevice,
                                    items: _availableDevices
                                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: _isRunning ? null : (v) => setState(() => _selectedDevice = v ?? _selectedDevice),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '判定しきい値: ${_similarityThreshold.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                                ),
                              ),
                              Slider(
                                value: _similarityThreshold,
                                min: 0.0,
                                max: 1.0,
                                divisions: 100,
                                label: _similarityThreshold.toStringAsFixed(2),
                                onChanged: _isRunning
                                    ? null
                                    : (v) => setState(() => _similarityThreshold = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // テストセット選択ボタン
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isRunning ? null : _pickTestSet,
                          icon: const Icon(Icons.folder_zip),
                          label: const Text('テストセットを選択', style: TextStyle(fontSize: 17)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ベンチマーク開始ボタン
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: (_isRunning || _testSetPath == null) ? null : _runBenchmark,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_isRunning ? '実行中...' : 'ベンチマーク開始', style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 選択中のファイル名
                      if (_testSetPath != null)
                        Text(
                          p.basename(_testSetPath!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'テストセットを選択して開始',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                          ),
                          textAlign: TextAlign.center,
                        ),

                      if (_processedImages > 0) ...[
                        const SizedBox(height: 32),
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '処理数',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.6 * 255).round())),
                                  ),
                                  Text(
                                    '$_processedImages/$_totalImages',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '精度',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.6 * 255).round())),
                                  ),
                                  Text(
                                    '${(_currentAccuracy * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '時間',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.6 * 255).round())),
                                  ),
                                  Text(
                                    '${(_elapsedTimeMs / 1000).toStringAsFixed(1)}s',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelManagement() {
    final colorScheme = Theme.of(context).colorScheme;
    final models = [..._models];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('モデル管理')),
              IconButton(
                tooltip: 'URL追加',
                onPressed: _isRunning
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _addModelFromUrl();
                      },
                icon: const Icon(Icons.add_link),
              ),
              IconButton(
                tooltip: 'ローカル取り込み',
                onPressed: _isRunning
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _importLocalModel();
                      },
                icon: const Icon(Icons.upload_file),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 500,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final isDownloaded = _modelsDownloaded[model.key] ?? false;
                final progress = _downloadProgress[model.key];
                final isDownloading = progress != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDownloaded
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isDownloaded ? Icons.check : Icons.cloud_download,
                        color: isDownloaded
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    title: Text(model.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${model.inputSize}x${model.inputSize}${model.isRecommended ? "  / 推奨" : ""}'),
                        if (isDownloading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(value: progress),
                          ),
                      ],
                    ),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isDownloaded
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteModel(model);
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.download),
                                tooltip: model.isRemote ? null : 'URLが無いモデルは取り込みで追加してください',
                                onPressed: (!model.isRemote)
                                    ? null
                                    : () async {
                                        await _downloadModel(model);
                                        if (mounted) {
                                          setDialogState(() {});
                                        }
                                      },
                              ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
