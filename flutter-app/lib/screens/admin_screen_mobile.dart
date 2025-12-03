import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者画面'),
        actions: [
          if (!_isLoading && _errorMessage == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllUsersData,
            ),
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
          // ジャンル別統計
          if (user.genreStats.isNotEmpty) ...[
            Text('ジャンル別', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            ...user.genreStats.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${e.key}: ${e.value.plays}回 (${e.value.averageScore.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 13),
              ),
            )),
            const SizedBox(height: 12),
          ],
          // 回答者別統計
          if (user.responderStats.isNotEmpty) ...[
            Text('回答者別', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            ...user.responderStats.entries.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${e.key.isEmpty ? "(未入力)" : e.key}: ${e.value.plays}回 (${e.value.averageScore.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 13),
              ),
            )),
            const SizedBox(height: 8),
            // 全回答者平均
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📊 全回答者平均: ${user.averageScore.toStringAsFixed(1)}% (${user.totalPlays}回)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 最近のプレイ履歴
          Text('最近のプレイ', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          const SizedBox(height: 8),
          ...user.histories.take(5).map((h) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_formatDate(h.timestamp)} - ${h.genre}: ${h.score}/${h.total} (${h.responderName.isEmpty ? "-" : h.responderName})',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          )),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// データクラス
class _UserData {
  final String uid;
  final List<_HistoryData> histories;

  _UserData({required this.uid, required this.histories});

  int get totalPlays => histories.length;
  int get totalQuestions => histories.fold(0, (sum, h) => sum + h.total);
  
  double get averageScore {
    if (histories.isEmpty) return 0.0;
    final totalScore = histories.fold(0, (sum, h) => sum + h.score);
    final totalQ = histories.fold(0, (sum, h) => sum + h.total);
    return totalQ > 0 ? (totalScore / totalQ) * 100 : 0.0;
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

  void add(_HistoryData h) {
    plays++;
    totalScore += h.score;
    totalQuestions += h.total;
  }

  double get averageScore => 
      totalQuestions > 0 ? (totalScore / totalQuestions) * 100 : 0.0;
}
