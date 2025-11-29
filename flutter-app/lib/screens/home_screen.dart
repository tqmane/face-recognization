import 'package:flutter/material.dart';
import 'quiz_screen.dart';
import 'test_set_screen.dart';
import '../services/quiz_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? bestScore;
  int? bestTime;

  @override
  void initState() {
    super.initState();
    _loadBestScores();
  }

  Future<void> _loadBestScores() async {
    // TODO: SharedPreferencesから読み込み
  }

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
                        '🔍',
                        style: TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // タイトル
                  Text(
                    '判別クイズ',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '似てる？同じ？判断しよう',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // ベストスコアカード
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ベストスコア',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bestScore != null 
                              ? '$bestScore 点 (${_formatTime(bestTime ?? 0)})'
                              : 'まだ記録がありません',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // オンラインモードボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => _showQuizOptions(context),
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('オンラインモード', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // テストセット管理ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TestSetScreen(),
                          ),
                        );
                      },
                      icon: const Text('📦', style: TextStyle(fontSize: 20)),
                      label: const Text('テストセット作成・管理', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '事前ダウンロードで高速テスト',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
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

  String _formatTime(int millis) {
    final seconds = millis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes分$secs秒';
    }
    return '$secs秒';
  }

  void _showQuizOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GenreSelectionDialog(
        onSelected: (genre) {
          Navigator.pop(context);
          _showQuestionCountDialog(context, genre);
        },
      ),
    );
  }

  void _showQuestionCountDialog(BuildContext context, Genre genre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('問題数を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              ('5問（お試し）', 5),
              ('10問', 10),
              ('15問', 15),
              ('20問', 20),
            ])
              ListTile(
                title: Text(option.$1),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        genre: genre,
                        questionCount: option.$2,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showQuizOptions(context);
            },
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }
}

class _GenreSelectionDialog extends StatelessWidget {
  final Function(Genre) onSelected;

  const _GenreSelectionDialog({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ジャンルを選択'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: Genre.values.map((genre) {
            return ListTile(
              title: Text(genre.displayName),
              subtitle: Text(genre.description, style: const TextStyle(fontSize: 12)),
              onTap: () => onSelected(genre),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
