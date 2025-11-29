import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/test_set_manager.dart';
import 'result_screen.dart';

class OfflineQuizScreen extends StatefulWidget {
  final TestSetInfo testSet;
  final int questionCount;

  const OfflineQuizScreen({
    super.key,
    required this.testSet,
    required this.questionCount,
  });

  @override
  State<OfflineQuizScreen> createState() => _OfflineQuizScreenState();
}

class _OfflineQuizScreenState extends State<OfflineQuizScreen> {
  final TestSetManager _testSetManager = TestSetManager();
  List<SavedQuestion> _questions = [];
  
  int _currentIndex = 0;
  int _score = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _timerText = '0:00';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions = await _testSetManager.loadTestSet(widget.testSet);
    questions.shuffle();
    
    setState(() {
      _questions = questions.take(widget.questionCount).toList();
      _isLoading = false;
    });
    
    _startQuiz();
  }

  void _startQuiz() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final seconds = _stopwatch.elapsed.inSeconds;
          final minutes = seconds ~/ 60;
          final secs = seconds % 60;
          _timerText = '$minutes:${secs.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _answer(bool isSame) {
    if (_currentIndex >= _questions.length) return;

    final correct = _questions[_currentIndex].isSame == isSame;
    if (correct) {
      _score++;
    }

    setState(() {
      _currentIndex++;
    });

    if (_currentIndex >= _questions.length) {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _stopwatch.stop();
    _timer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          score: _score,
          total: _questions.length,
          timeMillis: _stopwatch.elapsedMilliseconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(child: Text('問題の読み込みに失敗しました')),
      );
    }

    return _buildQuizScreen();
  }

  Widget _buildQuizScreen() {
    final question = _questions[_currentIndex];
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              color: colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Chip(
                    label: Text('📁 ${widget.testSet.genreName}'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                  const Spacer(),
                  Text(
                    _timerText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '問題 ${_currentIndex + 1} / ${_questions.length}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_score 点',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            // 画像
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: FutureBuilder<Uint8List?>(
                    future: _testSetManager.loadQuestionImage(widget.testSet, question),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ),
            
            // ボタン
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        onPressed: () => _answer(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          '✓ 同じ',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        onPressed: () => _answer(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          '✗ 違う',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
