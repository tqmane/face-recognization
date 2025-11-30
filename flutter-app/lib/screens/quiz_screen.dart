import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/quiz_manager.dart';
import '../services/image_scraper.dart';
import '../services/history_manager.dart';
import '../services/test_set_manager.dart';
import '../utils/app_colors.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final Genre genre;
  final int questionCount;
  final TestSetInfo? testSet; // テストセットからの読み込み用

  const QuizScreen({
    super.key,
    required this.genre,
    required this.questionCount,
    this.testSet,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ImageScraper _scraper = ImageScraper();
  final List<PreparedQuestion> _questions = [];
  
  bool _isLoading = true;
  bool _isCancelled = false;
  int _loadProgress = 0;
  
  // 名前入力
  bool _showNameInput = false;
  String _responderName = '';
  
  int _currentIndex = 0;
  int _score = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  
  // 問題ごとの結果を記録
  final List<QuestionResult> _questionResults = [];
  
  // タイマー用のValueNotifierで画像の再描画を防ぐ
  final ValueNotifier<String> _timerNotifier = ValueNotifier('0:00');

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    _isCancelled = true;
    super.dispose();
  }

  Future<void> _prepareQuestions() async {
    // テストセットがある場合はローカルファイルから読み込み
    if (widget.testSet != null) {
      await _loadFromTestSet();
      return;
    }
    
    // オンラインモード：画像をダウンロード
    await _downloadQuestions();
  }

  /// テストセットからローカルファイルを読み込み
  Future<void> _loadFromTestSet() async {
    final testSetManager = TestSetManager();
    final savedQuestions = await testSetManager.loadTestSet(widget.testSet!);
    
    // シャッフルして必要な問題数を選択
    savedQuestions.shuffle();
    final questionsToLoad = savedQuestions.take(widget.questionCount).toList();
    
    int loaded = 0;
    for (final saved in questionsToLoad) {
      if (_isCancelled) break;
      
      try {
        final imageFile = File('${widget.testSet!.dirPath}/${saved.imagePath}');
        if (await imageFile.exists()) {
          final imageData = await imageFile.readAsBytes();
          _questions.add(PreparedQuestion(
            imageData: imageData,
            isSame: saved.isSame,
            description: saved.description,
          ));
          loaded++;
          
          if (mounted) {
            setState(() {
              _loadProgress = (loaded * 100) ~/ widget.questionCount;
            });
          }
        }
      } catch (e) {
        // エラーは無視
      }
    }
    
    if (!_isCancelled && mounted) {
      setState(() {
        _isLoading = false;
        _showNameInput = true;
      });
    }
  }

  /// オンラインで画像をダウンロード
  Future<void> _downloadQuestions() async {
    final quizManager = QuizManager();
    
    // 問題設定を事前生成
    final configs = List.generate(
      widget.questionCount * 3,
      (_) => quizManager.generateQuestion(widget.genre),
    );

    int successCount = 0;
    int index = 0;

    while (successCount < widget.questionCount && 
           index < configs.length && 
           !_isCancelled) {
      final config = configs[index];
      index++;

      try {
        final imageData = config.isSame
            ? await _scraper.createSameImage(config.query1)
            : await _scraper.createComparisonImage(config.query1, config.query2);

        if (imageData != null && !_isCancelled) {
          _questions.add(PreparedQuestion(
            imageData: imageData,
            isSame: config.isSame,
            description: config.description,
          ));
          successCount++;
          
          if (mounted) {
            setState(() {
              _loadProgress = (successCount * 100) ~/ widget.questionCount;
            });
          }
        }
      } catch (e) {
        // エラーは無視して次へ
      }
    }

    if (!_isCancelled && mounted) {
      setState(() {
        _isLoading = false;
        _showNameInput = true;
      });
    }
  }

  void _startQuiz() {
    setState(() {
      _showNameInput = false;
    });
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final seconds = _stopwatch.elapsed.inSeconds;
        final minutes = seconds ~/ 60;
        final secs = seconds % 60;
        _timerNotifier.value = '$minutes:${secs.toString().padLeft(2, '0')}';
      }
    });
  }

  void _answer(bool isSame) {
    if (_currentIndex >= _questions.length) return;

    final question = _questions[_currentIndex];
    final correct = question.isSame == isSame;
    if (correct) {
      _score++;
    }
    
    // 結果を記録
    _questionResults.add(QuestionResult(
      questionNumber: _currentIndex + 1,
      description: question.description,
      isCorrect: correct,
      wasSame: question.isSame,
      answeredSame: isSame,
    ));

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
    
    // 履歴に保存
    final history = QuizHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      genre: widget.genre.displayName,
      responderName: _responderName,
      score: _score,
      total: _questions.length,
      timeMillis: _stopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
      questionResults: _questionResults,
    );
    HistoryManager.instance.saveHistory(history);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          score: _score,
          total: _questions.length,
          timeMillis: _stopwatch.elapsedMilliseconds,
          genre: widget.genre.displayName,
          responderName: _responderName,
          questionResults: _questionResults,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_showNameInput) {
      return _buildNameInputScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(
          child: Text('画像の取得に失敗しました'),
        ),
      );
    }

    return _buildQuizScreen();
  }
  
  Widget _buildNameInputScreen() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    '回答者の名前',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '任意入力（スキップ可）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    onChanged: (value) => _responderName = value,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      hintText: '例：山田太郎',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _startQuiz(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _responderName = '';
                            _startQuiz();
                          },
                          child: const Text('スキップ'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _startQuiz,
                          child: const Text('開始'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                '画像を準備中...',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${_questions.length} / ${widget.questionCount} 問',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _loadProgress / 100),
              const SizedBox(height: 8),
              Text('$_loadProgress%'),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  _isCancelled = true;
                  Navigator.pop(context);
                },
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    );
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
                    label: Text('🌐 ${widget.genre.displayName}'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                  const Spacer(),
                  ValueListenableBuilder<String>(
                    valueListenable: _timerNotifier,
                    builder: (context, timerText, _) => Text(
                      timerText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
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
                  child: Image.memory(
                    question.imageData,
                    fit: BoxFit.contain,
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
                          backgroundColor: context.successColor,
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
                          backgroundColor: context.errorColor,
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

class PreparedQuestion {
  final Uint8List imageData;
  final bool isSame;
  final String description;

  PreparedQuestion({
    required this.imageData,
    required this.isSame,
    required this.description,
  });
}
