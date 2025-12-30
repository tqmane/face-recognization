import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/zip_test_set_service.dart';
import '../services/history_manager.dart';
import 'result_screen.dart';

/// ZIPテストセット用のクイズ画面
/// 2枚の画像を別々に表示し、同じ種類か違う種類かを判定
class ZipQuizScreen extends StatefulWidget {
  final String testSetId;
  final String testSetName;
  final int questionCount;

  const ZipQuizScreen({
    super.key,
    required this.testSetId,
    required this.testSetName,
    required this.questionCount,
  });

  @override
  State<ZipQuizScreen> createState() => _ZipQuizScreenState();
}

class _ZipQuizScreenState extends State<ZipQuizScreen> {
  final ZipTestSetService _service = ZipTestSetService();
  List<ZipQuizQuestion> _questions = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  // 名前入力
  bool _showNameInput = false;
  String _responderName = '';
  final TextEditingController _nameController = TextEditingController();
  
  // カウントダウン
  bool _showCountdown = false;
  int _countdownValue = 3;
  
  int _currentIndex = 0;
  int _score = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  
  // 問題ごとの結果
  final List<QuestionResult> _questionResults = [];
  
  // フィードバック表示
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  bool _isAnswering = false;
  
  // タイマー表示
  final ValueNotifier<String> _timerNotifier = ValueNotifier('0:00');

  void _schedulePrecacheAround(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _precacheQuestionImages(index);
      await _precacheQuestionImages(index + 1);
    });
  }

  Future<void> _precacheQuestionImages(int index) async {
    if (kIsWeb) return;
    if (index < 0 || index >= _questions.length) return;
    final q = _questions[index];
    await precacheImage(FileImage(File(q.image1Path)), context);
    await precacheImage(FileImage(File(q.image2Path)), context);
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerNotifier.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _service.generateQuestions(
        widget.testSetId,
        widget.questionCount,
      );
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
          _showNameInput = true;
          _nameController.text = _responderName;
        });
        _schedulePrecacheAround(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startCountdown() {
    _responderName = _nameController.text.trim();
    setState(() {
      _showNameInput = false;
      _showCountdown = true;
      _countdownValue = 3;
    });
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdownValue--;
      });
      
      if (_countdownValue <= 0) {
        timer.cancel();
        _startQuiz();
      }
    });
  }

  void _startQuiz() {
    setState(() {
      _showCountdown = false;
    });
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        final elapsed = _stopwatch.elapsedMilliseconds;
        final seconds = elapsed ~/ 1000;
        final minutes = seconds ~/ 60;
        final secs = seconds % 60;
        _timerNotifier.value = '$minutes:${secs.toString().padLeft(2, '0')}';
      }
    });
  }

  void _answer(bool answeredSame) {
    if (_isAnswering || _showFeedback) return;
    
    setState(() {
      _isAnswering = true;
    });
    
    final question = _questions[_currentIndex];
    final isCorrect = (answeredSame == question.isSame);
    
    // 結果を記録
    _questionResults.add(QuestionResult(
      questionNumber: _currentIndex + 1,
      isCorrect: isCorrect,
      description: question.description,
      wasSame: question.isSame,
      answeredSame: answeredSame,
    ));
    
    if (isCorrect) {
      _score++;
    }
    
    // フィードバック表示
    setState(() {
      _showFeedback = true;
      _lastAnswerCorrect = isCorrect;
    });
    
    // フィードバック中はタイマーを一時停止
    _stopwatch.stop();
    
    // 1秒後に次の問題へ
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      
      // タイマーを再開
      _stopwatch.start();
      
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _showFeedback = false;
          _isAnswering = false;
        });
        _schedulePrecacheAround(_currentIndex);
      } else {
        await _finishQuiz();
      }
    });
  }

  Future<void> _finishQuiz() async {
    _stopwatch.stop();
    _timer?.cancel();
    
    final totalTime = _stopwatch.elapsedMilliseconds;
    
    // 履歴を保存
    final history = QuizHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      genre: widget.testSetName,
      responderName: _responderName,
      score: _score,
      total: _questions.length,
      timeMillis: totalTime,
      timestamp: DateTime.now(),
      questionResults: _questionResults,
    );
    
    await HistoryManager.instance.saveHistory(history);
    
    // 結果画面へ
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          score: _score,
          total: _questions.length,
          timeMillis: totalTime,
          genre: widget.testSetName,
          responderName: _responderName,
          questionResults: _questionResults,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.testSetName)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('問題を準備中...'),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.testSetName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('エラー: $_errorMessage'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_showNameInput) {
      return _buildNameInputScreen(colorScheme);
    }
    
    if (_showCountdown) {
      return _buildCountdownScreen(colorScheme);
    }
    
    return _buildQuizScreen(colorScheme);
  }

  Widget _buildNameInputScreen(ColorScheme colorScheme) {
    final recentNames = HistoryManager.instance.recentResponderNames;

    return Scaffold(
      appBar: AppBar(title: Text(widget.testSetName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🎯',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.questionCount}問のテスト',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '2枚の画像が同じ種類か判定してください',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  hintText: '入力しなくても大丈夫です',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _startCountdown(),
              ),
              if (recentNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近の名前',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in recentNames)
                      ActionChip(
                        label: Text(name),
                        onPressed: () {
                          setState(() {
                            _nameController.text = name;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _startCountdown,
                  child: const Text('スタート', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen(ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Text(
          '$_countdownValue',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テスト中断'),
        content: const Text('テストを中断しますか？\n進捗は保存されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('中断する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildQuizScreen(ColorScheme colorScheme) {
    final question = _questions[_currentIndex];
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmDialog();
        if (shouldExit && mounted) {
          _timer?.cancel();
          _stopwatch.stop();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldExit = await _showExitConfirmDialog();
              if (shouldExit && mounted) {
                _timer?.cancel();
                _stopwatch.stop();
                Navigator.pop(context);
              }
            },
          ),
          title: Text('${_currentIndex + 1} / ${_questions.length}'),
          actions: [
          ValueListenableBuilder<String>(
            valueListenable: _timerNotifier,
            builder: (context, time, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // プログレスバー
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
          
          // スコア表示
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'スコア: $_score / ${_currentIndex + (_showFeedback ? 1 : 0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          
          // 画像エリア
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 縦長なら縦並び、横長なら横並び
                      final isPortrait = constraints.maxHeight > constraints.maxWidth;
                      
                      if (isPortrait) {
                        return Column(
                          children: [
                            Expanded(
                              child: _buildImageCard(question.image1Path, '画像 A', colorScheme),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildImageCard(question.image2Path, '画像 B', colorScheme),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildImageCard(question.image1Path, '画像 A', colorScheme),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildImageCard(question.image2Path, '画像 B', colorScheme),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                
                // フィードバックオーバーレイ
                if (_showFeedback)
                  Container(
                    color: _lastAnswerCorrect
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: _lastAnswerCorrect ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _lastAnswerCorrect ? Icons.check_circle : Icons.cancel,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _lastAnswerCorrect ? '正解！' : '不正解',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              question.description,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 回答ボタン
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: FilledButton.tonal(
                      onPressed: _isAnswering ? null : () => _answer(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade900,
                      ),
                      child: const Text(
                        '同じ',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: FilledButton.tonal(
                      onPressed: _isAnswering ? null : () => _answer(false),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade900,
                      ),
                      child: const Text(
                        '違う',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),  // PopScopeの閉じ括弧
    );
  }

  Widget _buildImageCard(String imagePath, String label, ColorScheme colorScheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final cacheWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * dpr).round()
              : null;
          final cacheHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight * dpr).round()
              : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colorScheme.surfaceContainerHighest),
              Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
