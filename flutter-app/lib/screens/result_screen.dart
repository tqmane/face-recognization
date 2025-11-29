import 'package:flutter/material.dart';
import '../services/history_manager.dart';
import '../utils/app_colors.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final int timeMillis;
  final String genre;
  final String responderName;
  final List<QuestionResult> questionResults;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.timeMillis,
    required this.genre,
    required this.responderName,
    required this.questionResults,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = (score * 100) ~/ total;
    
    String grade;
    Color gradeColor;
    String emoji;
    
    if (percentage >= 90) {
      grade = '素晴らしい！';
      gradeColor = AppColors.warning;
      emoji = '🏆';
    } else if (percentage >= 70) {
      grade = 'よくできました！';
      gradeColor = context.successColor;
      emoji = '😊';
    } else if (percentage >= 50) {
      grade = 'まずまず';
      gradeColor = context.primaryColor;
      emoji = '🤔';
    } else {
      grade = 'もう一度挑戦！';
      gradeColor = context.warningColor;
      emoji = '💪';
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('結果'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 結果サマリー
                Center(
                  child: Column(
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        grade,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: gradeColor,
                        ),
                      ),
                      if (responderName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          responderName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // スコアカード
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$score',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              ' / $total 問正解',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: score / total,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              icon: Icons.percent,
                              label: '正解率',
                              value: '$percentage%',
                            ),
                            _StatItem(
                              icon: Icons.timer,
                              label: 'タイム',
                              value: _formatTime(timeMillis),
                            ),
                            _StatItem(
                              icon: Icons.category,
                              label: 'ジャンル',
                              value: genre,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 問題ごとの結果
                Text(
                  '問題ごとの結果',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...questionResults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;
                  return _QuestionResultItem(
                    index: index + 1,
                    result: result,
                  );
                }),
                const SizedBox(height: 32),
                
                // ボタン
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('ホームに戻る', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int millis) {
    final seconds = millis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes分$secs秒';
    }
    return '$secs秒';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuestionResultItem extends StatelessWidget {
  final int index;
  final QuestionResult result;

  const _QuestionResultItem({
    required this.index,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCorrect = result.isCorrect;
    final successColor = context.successColor;
    final errorColor = context.errorColor;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCorrect 
          ? successColor.withOpacity(0.1) 
          : errorColor.withOpacity(0.1),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCorrect ? successColor : errorColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isCorrect
                ? const Icon(Icons.check, color: Colors.white)
                : const Icon(Icons.close, color: Colors.white),
          ),
        ),
        title: Text(
          '問題 $index',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          result.description,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '正解: ${result.wasSame ? "同じ" : "違う"}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              '回答: ${result.answeredSame ? "同じ" : "違う"}',
              style: TextStyle(
                fontSize: 12,
                color: isCorrect ? successColor : errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
