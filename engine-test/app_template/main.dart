import 'dart:io';

import 'package:flutter/material.dart';
import 'package:engine_test/engine/mock_engine.dart';
import 'package:engine_test/firebase_sync.dart';
import 'package:engine_test/models/manifest.dart';
import 'package:engine_test/models/result_record.dart';
import 'package:engine_test/test_sets.dart';

void main() {
  runApp(const EngineTestApp());
}

class EngineTestApp extends StatelessWidget {
  const EngineTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engine Test',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const EngineTestHome(),
    );
  }
}

class EngineTestHome extends StatefulWidget {
  const EngineTestHome({super.key});

  @override
  State<EngineTestHome> createState() => _EngineTestHomeState();
}

class _EngineTestHomeState extends State<EngineTestHome> {
  String _setId = 'small_cats';
  int _questionCount = 10;
  final TextEditingController _runIdController =
      TextEditingController(text: _defaultRunId());
  final TextEditingController _dbUrlController = TextEditingController();
  final TextEditingController _idTokenController = TextEditingController();

  bool _isRunning = false;
  String _log = '';

  @override
  void dispose() {
    _runIdController.dispose();
    _dbUrlController.dispose();
    _idTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engine Test (Android)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSetSelector(),
                _buildQuestionCountSelector(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _runIdController,
              decoration: const InputDecoration(
                labelText: 'runId',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dbUrlController,
              decoration: const InputDecoration(
                labelText: 'Firebase RTDB URL (auth不要なら空でOK)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idTokenController,
              decoration: const InputDecoration(
                labelText: 'Firebase ID Token (空ならアップロードしない)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runTest,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_isRunning ? '実行中...' : 'テスト開始'),
                ),
                const SizedBox(width: 12),
                Text(
                  _isRunning ? '処理中です' : '人間テストと同じロジックで出題します',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ログ'),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log.isEmpty ? 'まだ実行していません' : _log,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetSelector() {
    return DropdownButton<String>(
      value: _setId,
      items: availableSetZips.keys
          .map((id) => DropdownMenuItem(value: id, child: Text(id)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _setId = v);
      },
    );
  }

  Widget _buildQuestionCountSelector() {
    return DropdownButton<int>(
      value: _questionCount,
      items: const [5, 10, 15, 20]
          .map((n) => DropdownMenuItem(value: n, child: Text('$n問')))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _questionCount = v);
      },
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _log = 'start: setId=$_setId, questions=$_questionCount\n';
    });

    final sb = StringBuffer(_log);
    final runId = _runIdController.text.trim().isEmpty
        ? _defaultRunId()
        : _runIdController.text.trim();
    FirebaseSync? sync;
    if (_dbUrlController.text.trim().isNotEmpty &&
        _idTokenController.text.trim().isNotEmpty) {
      sync = FirebaseSync(
        databaseUrl: _dbUrlController.text.trim(),
        idToken: _idTokenController.text.trim(),
      );
      sb.writeln('Firebase upload enabled');
    } else {
      sb.writeln('Firebase upload disabled (no URL/token)');
    }

    try {
      sb.writeln('Downloading set...');
      final zipPath = await downloadTestSetZip(_setId);
      sb.writeln('Zip: $zipPath');
      final manifest = await TestManifest.loadFromZip(zipPath);
      final questions = manifest.generatePairQuestions(_questionCount);
      sb.writeln('Generated ${questions.length} questions');

      final engine = MockEngine();
      int uploaded = 0;

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];

        final rec1 = await _inferOne(
          engine,
          q.image1,
          runId: runId,
          questionIndex: i + 1,
          isSame: q.isSame,
          type1: q.type1,
          type2: q.type2,
          position: 1,
          type1Display: q.type1Display,
          type2Display: q.type2Display,
        );

        final rec2 = await _inferOne(
          engine,
          q.image2,
          runId: runId,
          questionIndex: i + 1,
          isSame: q.isSame,
          type1: q.type1,
          type2: q.type2,
          position: 2,
          type1Display: q.type1Display,
          type2Display: q.type2Display,
        );

        if (sync != null) {
          await sync.uploadResult(runId, rec1);
          await sync.uploadResult(runId, rec2);
          uploaded += 2;
        }

        sb.writeln(
            'Q${i + 1}: ${q.type1} vs ${q.type2} (isSame=${q.isSame}) => rec1 ${rec1.latencyMs}ms, rec2 ${rec2.latencyMs}ms');
      }

      sb.writeln('done. uploaded=$uploaded records. runId=$runId');
    } catch (e, st) {
      sb.writeln('ERROR: $e\n$st');
    }

    if (mounted) {
      setState(() {
        _log = sb.toString();
        _isRunning = false;
      });
    }
  }

  Future<ResultRecord> _inferOne(
    MockEngine engine,
    TestItem item, {
    required String runId,
    required int questionIndex,
    required bool isSame,
    required String type1,
    required String type2,
    required int position,
    String? type1Display,
    String? type2Display,
  }) async {
    final bytes = await File(item.resolvedPath).readAsBytes();
    final result = await engine.infer(bytes);
    return ResultRecord(
      runId: runId,
      imageId: 'q${questionIndex}_$position',
      engine: engine.name,
      provider: result.provider,
      latencyMs: result.latencyMs,
      predictions: result.predictions,
      inputSize: result.inputSize,
      preprocess: result.note ?? 'none (match human test)',
      label: item.label,
      meta: {
        'questionIndex': questionIndex,
        'isSame': isSame,
        'type1': type1,
        'type2': type2,
        'position': position,
        if (type1Display != null) 'type1Display': type1Display,
        if (type2Display != null) 'type2Display': type2Display,
      },
      imagePath: item.resolvedPath,
    );
  }
}

String _defaultRunId() =>
    DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
