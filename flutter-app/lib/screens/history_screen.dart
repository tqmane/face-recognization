import 'package:flutter/material.dart';
import '../services/history_manager.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テスト結果一覧'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '履歴'),
            Tab(text: 'ジャンル別'),
            Tab(text: '全体統計'),
            Tab(text: '回答者別'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HistoryListTab(),
          _GenreStatsTab(),
          _OverallStatsTab(),
          _ResponderStatsTab(),
        ],
      ),
    );
  }
  
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除'),
        content: const Text('全ての履歴を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HistoryManager.instance.clearHistories();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// 履歴一覧タブ
class _HistoryListTab extends StatelessWidget {
  const _HistoryListTab();

  @override
  Widget build(BuildContext context) {
    final histories = HistoryManager.instance.histories;
    
    if (histories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('まだ履歴がありません'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: histories.length,
      itemBuilder: (context, index) {
        final history = histories[index];
        return _HistoryCard(history: history);
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QuizHistory history;
  
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = history.accuracy.round();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(history.genre),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(history.timestamp),
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (history.responderName.isNotEmpty) ...[
                    Icon(Icons.person, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text(
                      history.responderName,
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    '${history.score}/${history.total}問正解',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPercentageColor(percentage).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getPercentageColor(percentage),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(history.timeMillis),
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${history.genre} - 詳細'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.questionResults.length,
            itemBuilder: (context, index) {
              final result = history.questionResults[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: result.isCorrect ? Colors.green : Colors.red,
                  child: Icon(
                    result.isCorrect ? Icons.check : Icons.close,
                    color: Colors.white,
                  ),
                ),
                title: Text('問題 ${result.questionNumber}'),
                subtitle: Text(result.description),
                trailing: Text(
                  result.answeredSame ? '同じ' : '違う',
                  style: TextStyle(
                    color: result.isCorrect ? Colors.green : Colors.red,
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
    );
  }
  
  Color _getPercentageColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

/// ジャンル別統計タブ
class _GenreStatsTab extends StatelessWidget {
  const _GenreStatsTab();

  @override
  Widget build(BuildContext context) {
    final statsByGenre = HistoryManager.instance.getStatsByGenre();
    
    if (statsByGenre.isEmpty) {
      return const Center(
        child: Text('まだデータがありません'),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: statsByGenre.entries.map((entry) {
        return _StatsCard(stats: entry.value);
      }).toList(),
    );
  }
}

/// 全体統計タブ
class _OverallStatsTab extends StatelessWidget {
  const _OverallStatsTab();

  @override
  Widget build(BuildContext context) {
    final stats = HistoryManager.instance.getOverallStats();
    
    if (stats.totalTests == 0) {
      return const Center(
        child: Text('まだデータがありません'),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _StatsCard(stats: stats, isLarge: true),
    );
  }
}

/// 回答者別統計タブ
class _ResponderStatsTab extends StatelessWidget {
  const _ResponderStatsTab();

  @override
  Widget build(BuildContext context) {
    final statsByResponder = HistoryManager.instance.getStatsByResponder();
    
    if (statsByResponder.isEmpty) {
      return const Center(
        child: Text('まだデータがありません'),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: statsByResponder.entries.map((entry) {
        return _StatsCard(stats: entry.value, icon: Icons.person);
      }).toList(),
    );
  }
}

/// 統計カード
class _StatsCard extends StatelessWidget {
  final GenreStats stats;
  final bool isLarge;
  final IconData? icon;
  
  const _StatsCard({
    required this.stats,
    this.isLarge = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  stats.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _StatItem(
                  label: 'テスト数',
                  value: '${stats.totalTests}回',
                  icon: Icons.quiz,
                ),
                _StatItem(
                  label: '平均正答率',
                  value: '${stats.averageAccuracy.toStringAsFixed(1)}%',
                  icon: Icons.percent,
                  color: _getPercentageColor(stats.averageAccuracy.round()),
                ),
                _StatItem(
                  label: '平均得点',
                  value: stats.averageScore.toStringAsFixed(1),
                  icon: Icons.star,
                ),
                _StatItem(
                  label: '総問題数',
                  value: '${stats.totalQuestions}問',
                  icon: Icons.format_list_numbered,
                ),
                _StatItem(
                  label: '総正解数',
                  value: '${stats.totalCorrect}問',
                  icon: Icons.check_circle,
                ),
                _StatItem(
                  label: '平均時間',
                  value: _formatTime(stats.averageTime.round()),
                  icon: Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getPercentageColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
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
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Icon(icon, size: 24, color: color ?? colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
