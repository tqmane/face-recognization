import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_sync_service.dart';
import 'package:firebase_database/firebase_database.dart';

/// モバイル向け管理者画面
/// 全ユーザーのプレイデータを閲覧
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const String _adminUid = 'fwtzsOcnjjWQhwkIRJDfpF0iIY52';
  
  bool _isLoading = true;
  String? _errorMessage;
  List<_UserData> _usersData = [];
  final Set<String> _expandedUsers = {};

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  void _checkAccessAndLoad() {
    final syncService = FirebaseSyncService.instance;
    
    if (!syncService.isSignedIn) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ログインしていません';
      });
      return;
    }
    
    final currentUserId = syncService.currentUser?.uid;
    if (currentUserId != _adminUid) {
      setState(() {
        _isLoading = false;
        _errorMessage = '管理者権限がありません';
      });
      return;
    }
    
    _loadAllUsersData();
  }

  Future<void> _loadAllUsersData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users').get();
      
      if (!snapshot.exists) {
        setState(() {
          _isLoading = false;
          _usersData = [];
        });
        return;
      }

      final usersData = <_UserData>[];
      final data = snapshot.value as Map<dynamic, dynamic>?;
      
      if (data != null) {
        for (final entry in data.entries) {
          final uid = entry.key as String;
          final userData = entry.value as Map<dynamic, dynamic>?;
          
          if (userData != null) {
            final histories = <_HistoryData>[];
            final historiesData = userData['histories'] as Map<dynamic, dynamic>?;
            
            if (historiesData != null) {
              for (final historyEntry in historiesData.entries) {
                try {
                  final historyMap = historyEntry.value as Map<dynamic, dynamic>;
                  histories.add(_HistoryData(
                    id: historyMap['id'] as String? ?? '',
                    genre: historyMap['genre'] as String? ?? '',
                    responderName: historyMap['responderName'] as String? ?? '',
                    score: (historyMap['score'] as num?)?.toInt() ?? 0,
                    total: (historyMap['total'] as num?)?.toInt() ?? 0,
                    timeMillis: (historyMap['timeMillis'] as num?)?.toInt() ?? 0,
                    timestamp: (historyMap['timestamp'] as num?)?.toInt() ?? 0,
                  ));
                } catch (e) {
                  // Skip invalid entries
                }
              }
            }
            
            histories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            usersData.add(_UserData(uid: uid, histories: histories));
          }
        }
      }
      
      usersData.sort((a, b) => b.totalPlays.compareTo(a.totalPlays));
      
      setState(() {
        _isLoading = false;
        _usersData = usersData;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'データの読み込みに失敗しました: $e';
      });
    }
  }
  
  void _showCurrentUid() {
    final uid = FirebaseSyncService.instance.currentUser?.uid ?? '不明';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('あなたのUID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('このUIDを管理者として設定できます:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      uid,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UIDをコピーしました'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者画面'),
        actions: [
          if (!_isLoading && _errorMessage == null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _loadAllUsersData,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'あなたのUID',
              onPressed: _showCurrentUid,
            ),
          ],
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _errorMessage!.contains('ログイン') 
                    ? Icons.login 
                    : Icons.block,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_usersData.isEmpty) {
      return const Center(
        child: Text('データがありません'),
      );
    }

    return Column(
      children: [
        // サマリーカード
        _buildSummaryCard(colorScheme),
        const Divider(height: 1),
        // ユーザーリスト
        Expanded(
          child: ListView.builder(
            itemCount: _usersData.length,
            itemBuilder: (context, index) {
              return _buildUserCard(_usersData[index], colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    final totalUsers = _usersData.length;
    final totalPlays = _usersData.fold(0, (sum, u) => sum + u.totalPlays);
    final totalQuestions = _usersData.fold(0, (sum, u) => sum + u.totalQuestions);

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('ユーザー数', totalUsers.toString(), colorScheme),
          _buildSummaryItem('総プレイ数', totalPlays.toString(), colorScheme),
          _buildSummaryItem('総問題数', totalQuestions.toString(), colorScheme),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(_UserData user, ColorScheme colorScheme) {
    final isExpanded = _expandedUsers.contains(user.uid);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: Text(
                '${_usersData.indexOf(user) + 1}',
                style: TextStyle(color: colorScheme.onPrimary),
              ),
            ),
            title: Text(
              'UID: ${user.uid.substring(0, 8)}...',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            subtitle: Text(
              'プレイ: ${user.totalPlays}回 | 正答率: ${user.averageScore.toStringAsFixed(1)}%',
            ),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedUsers.remove(user.uid);
                  } else {
                    _expandedUsers.add(user.uid);
                  }
                });
              },
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildUserDetails(user, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildUserDetails(_UserData user, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UID別全回答者平均（独立セクション）
          if (user.histories.isNotEmpty) ...[
            Text('UID別全回答者平均', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            _buildStatsTable({'全回答者平均': user.overallStats}, colorScheme),
            const SizedBox(height: 16),
          ],
          // ジャンル別統計（テーブル形式）
          if (user.genreStats.isNotEmpty) ...[
            Text('ジャンル別統計', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            _buildStatsTable(user.genreStats, colorScheme),
            const SizedBox(height: 16),
          ],
          // 回答者別統計（テーブル形式）
          if (user.responderStats.isNotEmpty) ...[
            Text('回答者別統計', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            _buildStatsTable(user.responderStats, colorScheme, isResponder: true),
            const SizedBox(height: 16),
          ],
          // 最近のプレイ履歴
          Text('最近のプレイ履歴', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // ヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 2, child: Text('日時', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('ジャンル', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('回答者', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 1, child: Text('結果', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      const Expanded(flex: 1, child: Text('時間', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                // データ行
                ...user.histories.take(10).map((h) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(_formatDate(h.timestamp), style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(h.genre, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 2, child: Text(h.responderName.isEmpty ? '-' : h.responderName, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text('${h.score}/${h.total}', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text(_formatTime(h.timeMillis), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsTable(Map<String, _GenreStats> stats, ColorScheme colorScheme, {bool isResponder = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(isResponder ? '回答者' : 'ジャンル', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: Text('回数', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                const Expanded(flex: 2, child: Text('正答率', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                const Expanded(flex: 1, child: Text('平均点', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                const Expanded(flex: 2, child: Text('平均時間', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // データ行
          ...stats.entries.map((e) {
            final name = e.key.isEmpty ? '(未入力)' : e.key;
            final stat = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 1, child: Text('${stat.plays}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${stat.averageScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text(stat.averagePoints.toStringAsFixed(1), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(stat.formattedAverageTime, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(int millis) {
    final seconds = millis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

// データクラス
class _UserData {
  final String uid;
  final List<_HistoryData> histories;

  _UserData({required this.uid, required this.histories});

  int get totalPlays => histories.length;
  int get totalQuestions => histories.fold(0, (sum, h) => sum + h.total);
  int get totalScore => histories.fold(0, (sum, h) => sum + h.score);
  int get totalTimeMillis => histories.fold(0, (sum, h) => sum + h.timeMillis);
  
  double get averageScore {
    if (histories.isEmpty) return 0.0;
    return totalQuestions > 0 ? (totalScore / totalQuestions) * 100 : 0.0;
  }
  
  double get averagePoints {
    if (histories.isEmpty) return 0.0;
    return totalScore / histories.length;
  }
  
  String get formattedAverageTime {
    if (histories.isEmpty) return '0:00';
    final avgMillis = totalTimeMillis ~/ histories.length;
    final seconds = avgMillis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, _GenreStats> get genreStats {
    final stats = <String, _GenreStats>{};
    for (final h in histories) {
      stats.putIfAbsent(h.genre, () => _GenreStats()).add(h);
    }
    return stats;
  }

  Map<String, _GenreStats> get responderStats {
    final stats = <String, _GenreStats>{};
    for (final h in histories) {
      stats.putIfAbsent(h.responderName, () => _GenreStats()).add(h);
    }
    return stats;
  }

  // UID別全回答者平均
  _GenreStats get overallStats {
    final stats = _GenreStats();
    for (final h in histories) {
      stats.add(h);
    }
    return stats;
  }
}

class _HistoryData {
  final String id;
  final String genre;
  final String responderName;
  final int score;
  final int total;
  final int timeMillis;
  final int timestamp;

  _HistoryData({
    required this.id,
    required this.genre,
    required this.responderName,
    required this.score,
    required this.total,
    required this.timeMillis,
    required this.timestamp,
  });
}

class _GenreStats {
  int plays = 0;
  int totalScore = 0;
  int totalQuestions = 0;
  int totalTimeMillis = 0;

  void add(_HistoryData h) {
    plays++;
    totalScore += h.score;
    totalQuestions += h.total;
    totalTimeMillis += h.timeMillis;
  }

  double get averageScore => 
      totalQuestions > 0 ? (totalScore / totalQuestions) * 100 : 0.0;
  
  double get averagePoints => 
      plays > 0 ? totalScore / plays : 0.0;
  
  String get formattedAverageTime {
    if (plays == 0) return '0:00';
    final avgMillis = totalTimeMillis ~/ plays;
    final seconds = avgMillis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
