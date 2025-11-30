import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/history_manager.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 選択モード関連
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _exitSelectionMode();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }
  
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
    });
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }
  
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedIds.length}件選択中' : 'テスト結果一覧'),
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : null,
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
          // 選択削除ボタン（履歴タブのみ）
          if (_tabController.index == 0)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.delete : Icons.checklist),
              tooltip: _isSelectionMode ? '選択項目を削除' : '選択削除',
              onPressed: () {
                if (_isSelectionMode) {
                  if (_selectedIds.isNotEmpty) {
                    _showDeleteSelectedDialog();
                  }
                } else {
                  _enterSelectionMode();
                }
              },
            ),
          // 全削除ボタン
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '全削除',
            onPressed: () => _showClearDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryListTab(
            isSelectionMode: _isSelectionMode,
            selectedIds: _selectedIds,
            onTap: (history) {
              if (_isSelectionMode) {
                _toggleSelection(history.id);
              } else {
                _showDetailDialog(context, history);
              }
            },
            onLongPress: (history) {
              if (!_isSelectionMode) {
                _showDeleteSingleDialog(history);
              }
            },
            onSecondaryTap: (history) {
              _showDeleteSingleDialog(history);
            },
            onSelectionChanged: (id, isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
              });
            },
            isDesktop: _isDesktop,
          ),
          const _GenreStatsTab(),
          const _OverallStatsTab(),
          const _ResponderStatsTab(),
        ],
      ),
    );
  }
  
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全履歴を削除'),
        content: const Text('全ての履歴を削除しますか？\nこの操作は取り消せません。'),
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
                _exitSelectionMode();
                setState(() {});
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteSelectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選択した履歴を削除'),
        content: Text('${_selectedIds.length}件の履歴を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HistoryManager.instance.deleteHistories(_selectedIds);
              if (mounted) {
                Navigator.pop(context);
                _exitSelectionMode();
                setState(() {});
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteSingleDialog(QuizHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除'),
        content: Text('「${history.genre}」の履歴を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HistoryManager.instance.deleteHistory(history.id);
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
  
  void _showDetailDialog(BuildContext context, QuizHistory history) {
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
}

/// 履歴一覧タブ
class _HistoryListTab extends StatelessWidget {
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final void Function(QuizHistory) onTap;
  final void Function(QuizHistory) onLongPress;
  final void Function(QuizHistory) onSecondaryTap;
  final void Function(String, bool) onSelectionChanged;
  final bool isDesktop;
  
  const _HistoryListTab({
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
    required this.onSelectionChanged,
    required this.isDesktop,
  });

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
        return _HistoryCard(
          history: history,
          isSelectionMode: isSelectionMode,
          isSelected: selectedIds.contains(history.id),
          onTap: () => onTap(history),
          onLongPress: () => onLongPress(history),
          onSecondaryTap: () => onSecondaryTap(history),
          onSelectionChanged: (isSelected) => onSelectionChanged(history.id, isSelected),
          isDesktop: isDesktop,
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QuizHistory history;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSecondaryTap;
  final void Function(bool) onSelectionChanged;
  final bool isDesktop;
  
  const _HistoryCard({
    required this.history,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
    required this.onSelectionChanged,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = history.accuracy.round();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? colorScheme.primaryContainer.withOpacity(0.5) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: isDesktop ? null : onLongPress, // モバイルは長押し
        onSecondaryTap: isDesktop ? onSecondaryTap : null, // デスクトップは右クリック
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // チェックボックス（選択モード時のみ）
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged(value ?? false),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
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
                        if (isDesktop) ...[
                          const Spacer(),
                          Text(
                            '右クリックで削除',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
