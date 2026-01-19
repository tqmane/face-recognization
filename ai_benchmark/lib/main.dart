import 'dart:io';
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
  String _selectedModelKey = 'MobileNet V2';
  String _selectedDevice = 'CPU';
  String? _testSetPath;
  bool _isRunning = false;
  double _progress = 0.0;
  String _statusMessage = 'Checking hardware...';

  // Hardware status
  Map<String, bool> _hardwareStatus = {'CPU': true, 'GPU': false, 'NNAPI': false};
  List<String> _availableDevices = ['CPU'];

  // Models status - individual download tracking
  Map<String, bool> _modelsDownloaded = {};
  Map<String, double> _downloadProgress = {};
  bool _isLoadingModels = true;

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
    for (final model in ModelManager.models) {
      downloadedStatus[model.key] = await manager.isModelDownloaded(model.key);
    }

    if (!mounted) return;

    setState(() {
      _modelsDownloaded = downloadedStatus;
      _isLoadingModels = false;
    });

    // Check if at least one model is downloaded
    final hasAnyModel = _modelsDownloaded.values.any((downloaded) => downloaded);
    if (!hasAnyModel) {
      setState(() {
        _statusMessage = 'モデルをダウンロードしてください';
      });
      return;
    }

    // Hardware Check
    final checker = HardwareChecker();
    final firstModelKey = _modelsDownloaded.entries.firstWhere(
      (e) => e.value,
      orElse: () => MapEntry(ModelManager.models.first.key, true),
    ).key;
    final modelFile = await manager.getModelFile(firstModelKey);
    final status = await checker.checkAvailability(modelFile.path);

    if (!mounted) return;

    setState(() {
      _hardwareStatus = status;
      _availableDevices = status.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      if (_availableDevices.contains('GPU')) {
        _selectedDevice = 'GPU';
      } else if (_availableDevices.contains('NNAPI')) {
        _selectedDevice = 'NNAPI';
      } else {
        _selectedDevice = 'CPU';
      }

      _statusMessage = '準備完了: ${_availableDevices.join(", ")}';
    });

    // Set default selected model to first downloaded one
    final downloadedModels = ModelManager.models.where((m) => _modelsDownloaded[m.key] == true).toList();
    if (downloadedModels.isNotEmpty && mounted) {
      setState(() {
        _selectedModelKey = downloadedModels.first.name;
      });
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
      setState(() {
        _modelsDownloaded[model.key] = false;
      });
      if (mounted) {
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

  Future<void> _pickTestSet() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }

    String? path;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      path = result.files.single.path;
    } else if (!Platform.isAndroid && !Platform.isIOS) {
       path = await FilePicker.platform.getDirectoryPath();
    }

    if (path != null) {
      setState(() {
        _testSetPath = path;
        _statusMessage = '選択中: ${p.basename(path!)}';
      });
    }
  }

  Future<InferenceEngine?> _createEngine(String key, String device) async {
    if (key == 'Histogram') {
      return HistogramEngine();
    }

    final modelInfo = ModelManager.models.firstWhere(
      (m) => m.name == key,
      orElse: () => ModelManager.models.first
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
      await engine.initialize();

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

      for (int i = 0; i < questions.length; i++) {
        if (!mounted) break;

        final q = questions[i];
        final start = DateTime.now();

        double similarity = 0.0;
        try {
          similarity = await engine.compareImages(q.image1Url, q.image2Url);
        } catch (e) {
          print('Inference error at index $i: $e');
        }

        final elapsed = DateTime.now().difference(start).inMilliseconds;

        bool predictedSame = similarity > 0.85;
        bool isCorrect = (predictedSame == q.isMatch);
        if (isCorrect) correctCount++;

        _results.add(InferenceResult(
          questionId: i + 1,
          genre: q.genre,
          isSameActual: q.isMatch,
          isSamePredicted: predictedSame,
          similarityScore: similarity,
          inferenceTimeMs: elapsed,
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
      engine.dispose();
      await _exportResults();

      setState(() {
        _statusMessage = '完了！精度: ${(_currentAccuracy * 100).toStringAsFixed(1)}%';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
      });
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _exportResults() async {
    List<List<dynamic>> rows = [];
    rows.add([
      'Question ID', 'Genre', 'Actual Match', 'Predicted Match', 'Correct', 'Similarity Score', 'Time (ms)',
      'Model', 'Device'
    ]);

    for (var r in _results) {
      rows.add([
        r.questionId, r.genre, r.isSameActual, r.isSamePredicted,
        r.isSameActual == r.isSamePredicted, r.similarityScore, r.inferenceTimeMs,
        _selectedModelKey, _selectedDevice
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/benchmark_${_selectedModelKey.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存しました: ${file.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyModel = _modelsDownloaded.values.any((downloaded) => downloaded);

    // モデルがない場合はダウンロード画面を表示
    if (!hasAnyModel && !_isLoadingModels) {
      return _ModelDownloadScreen(
        modelsDownloaded: _modelsDownloaded,
        downloadProgress: _downloadProgress,
        onDownloadModel: _downloadModel,
        onDownloadComplete: _checkSystem,
      );
    }

    if (_isLoadingModels) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final downloadedModels = ModelManager.models.where((m) => _modelsDownloaded[m.key] == true).toList();

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
                          color: colorScheme.onSurface.withOpacity(0.6),
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
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right, color: colorScheme.onSurface.withOpacity(0.4)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'モデル',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                value: hasAnyModel ? _selectedModelKey : null,
                                items: downloadedModels.isEmpty
                                    ? null
                                    : downloadedModels
                                        .map((m) => DropdownMenuItem(
                                            value: m.name,
                                            child: Text(m.name),
                                          ))
                                        .toList(),
                                onChanged: (hasAnyModel && !_isRunning)
                                    ? (v) => setState(() => _selectedModelKey = v!)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'デバイス',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                value: _selectedDevice,
                                items: _availableDevices
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                    .toList(),
                                onChanged: _isRunning ? null : (v) => setState(() => _selectedDevice = v!),
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
                          onPressed: (_isRunning || !hasAnyModel) ? null : _pickTestSet,
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
                          onPressed: (_isRunning || _testSetPath == null || !hasAnyModel) ? null : _runBenchmark,
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
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'テストセットを選択して開始',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
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
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
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
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
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
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
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
                          color: colorScheme.onSurface.withOpacity(0.6),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('モデル管理'),
          content: SizedBox(
            width: 400,
            height: 500,
            child: ListView.builder(
              itemCount: ModelManager.models.length,
              itemBuilder: (context, index) {
                final model = ModelManager.models[index];
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
                        Text('${model.inputSize}x${model.inputSize}'),
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
                                onPressed: () async {
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

/// モデルダウンロード画面
class _ModelDownloadScreen extends StatelessWidget {
  final Map<String, bool> modelsDownloaded;
  final Map<String, double> downloadProgress;
  final Function(ModelItem) onDownloadModel;
  final VoidCallback onDownloadComplete;

  const _ModelDownloadScreen({
    required this.modelsDownloaded,
    required this.downloadProgress,
    required this.onDownloadModel,
    required this.onDownloadComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
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
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // モデルリスト見出し
                  Text(
                    'モデルをダウンロード',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // モデルリスト
                  Expanded(
                    child: ListView.builder(
                      itemCount: ModelManager.models.length,
                      itemBuilder: (context, index) {
                        final model = ModelManager.models[index];
                        final isDownloaded = modelsDownloaded[model.key] ?? false;
                        final progress = downloadProgress[model.key];
                        final isDownloading = progress != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
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
                                Text('${model.inputSize}x${model.inputSize}'),
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
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () => onDownloadModel(model),
                                      ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 完了ボタン（いずれかのモデルがダウンロード済みの場合）
                  if (modelsDownloaded.values.any((d) => d))
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: onDownloadComplete,
                        icon: const Icon(Icons.check),
                        label: const Text('完了', style: TextStyle(fontSize: 17)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
