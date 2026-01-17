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
  String _selectedModelKey = 'Histogram';
  String _selectedDevice = 'CPU';
  String? _testSetPath;
  bool _isRunning = false;
  double _progress = 0.0;
  String _statusMessage = 'Checking hardware...';
  
  // Hardware status
  Map<String, bool> _hardwareStatus = {'CPU': true, 'GPU': false, 'NNAPI': false};
  List<String> _availableDevices = ['CPU'];

  // Models status
  bool _modelsReady = false;
  Map<String, double> _downloadProgress = {};

  // Stats
  int _totalImages = 0;
  int _processedImages = 0;
  double _currentAccuracy = 0.0;
  int _elapsedTimeMs = 0;
  List<InferenceResult> _results = [];

  final List<String> _devices = ['CPU', 'GPU'];

  @override
  void initState() {
    super.initState();
    _checkSystem();
  }

  Future<void> _checkSystem() async {
    // 1. Model Check
    final modelManager = ModelManager();
    final ready = await modelManager.areAllModelsDownloaded();

    if (!ready) {
      setState(() {
        _modelsReady = false;
        _statusMessage = 'Models need to be downloaded.';
      });
      return;
    }

    // 2. Hardware Check (only if models exist)
    final checker = HardwareChecker();
    // Use the first model for checking
    final modelFile = await modelManager.getModelFile(ModelManager.models.first.key);
    final status = await checker.checkAvailability(modelFile.path);

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
      
      _modelsReady = true;
      _statusMessage = 'Ready. Hardware: ${_availableDevices.join(", ")}';
    });
  }

  Future<void> _downloadModels() async {
    final manager = ModelManager();
    
    for (var model in ModelManager.models) {
      if (await manager.isModelDownloaded(model.key)) continue;

      setState(() => _statusMessage = 'Downloading ${model.name}...');
      
      try {
        await manager.downloadModel(model.key, (progress) {
          setState(() {
            _downloadProgress[model.key] = progress;
          });
        });
      } catch (e) {
        setState(() => _statusMessage = 'Failed to download ${model.name}: $e');
        return;
      }
    }

    // Re-check system now that models are available
    await _checkSystem();
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
        _statusMessage = 'Selected: ${p.basename(path!)}';
      });
    }
  }

  Future<InferenceEngine?> _createEngine(String key, String device) async {
    if (key == 'Histogram') {
      return HistogramEngine();
    }
    
    // Find model info
    final modelInfo = ModelManager.models.firstWhere(
      (m) => m.name == key, 
      orElse: () => ModelManager.models.first
    );
    
    final manager = ModelManager();
    final file = await manager.getModelFile(modelInfo.key);
    
    if (!await file.exists()) {
      setState(() => _statusMessage = 'Model file not found: ${file.path}');
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
      _statusMessage = 'Initializing ${engine.name}...';
    });

    try {
      await engine.initialize();

      setState(() => _statusMessage = 'Loading test set...');
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
          _statusMessage = 'Processing ${i+1}/$_totalImages...';
        });
        
        await Future.delayed(Duration.zero);
      }
      
      stopwatch.stop();
      engine.dispose();
      await _exportResults();

      setState(() {
        _statusMessage = 'Complete! Accuracy: ${(_currentAccuracy * 100).toStringAsFixed(1)}%';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
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
        SnackBar(content: Text('Saved to: ${file.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_modelsReady && !_isRunning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Download Models')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_download, size: 64, color: Colors.teal),
              const SizedBox(height: 20),
              const Text('AI Models need to be downloaded first.'),
              const SizedBox(height: 20),
              ...ModelManager.models.map((m) {
                double p = _downloadProgress[m.key] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(m.name), Text('${(p * 100).toInt()}%')],
                      ),
                      LinearProgressIndicator(value: p),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: _downloadModels,
                child: const Text('Download All Models'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Benchmark Runner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blueGrey.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.hardware, size: 20),
                  const SizedBox(width: 8),
                  Text('Detected: ${_availableDevices.join(", ")}'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Engine'),
                      value: _selectedModelKey,
                      items: ['Histogram', ...ModelManager.models.map((m) => m.name)]
                          .map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                      onChanged: _isRunning ? null : (v) => setState(() => _selectedModelKey = v!),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Device'),
                      value: _selectedDevice,
                      items: _availableDevices.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: _isRunning ? null : (v) => setState(() => _selectedDevice = v!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _pickTestSet,
              icon: const Icon(Icons.folder_zip),
              label: Text(_testSetPath == null ? 'Select Test Set (ZIP/Folder)' : 'Change Test Set'),
            ),
            if (_testSetPath != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(p.basename(_testSetPath!)),
              ),
              
            const Spacer(),
            
            if (_processedImages > 0) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBox(label: 'Count', value: '$_processedImages / $_totalImages'),
                  _StatBox(label: 'Accuracy', value: '${(_currentAccuracy * 100).toStringAsFixed(1)}%'),
                  _StatBox(label: 'Time', value: '${(_elapsedTimeMs / 1000).toStringAsFixed(1)}s'),
                ],
              ),
            ],
            
            const SizedBox(height: 20),
            Text(_statusMessage, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isRunning || _testSetPath == null ? null : _runBenchmark,
                child: const Text('START BENCHMARK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}