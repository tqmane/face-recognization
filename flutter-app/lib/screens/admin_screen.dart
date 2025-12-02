import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_sync_service.dart';
import '../services/firebase_init.dart';

bool get _isMobile {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

bool get _isDesktop {
  if (kIsWeb) return false;
  try {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  } catch (e) {
    return false;
  }
}

/// 管理者画面 - 全ユーザーのプレイデータを閲覧
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _syncService = FirebaseSyncService.instance;
  bool _isLoading = false;
  bool _isAdmin = false;
  String? _errorMessage;
  
  // 全ユーザーのデータ
  Map<String, UserData> _allUsersData = {};
  
  // 管理者のUID
  static const String _adminUid = 'fwtzsOcnjjWQhwkIRJDfpF0iIY52';
  
  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }
  
  void _checkAdminStatus() {
    final currentUser = _syncService.currentUser;
    if (currentUser != null) {
      // 現在のユーザーが管理者かチェック
      _isAdmin = currentUser.uid == _adminUid;
      
      if (_isAdmin) {
        _loadAllUsersData();
      }
    }
  }
  
  Future<void> _loadAllUsersData() async {
    if (!isFirebaseInitialized) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users').get();
      
      if (!snapshot.exists) {
        setState(() {
          _allUsersData = {};
          _isLoading = false;
        });
        return;
      }
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      final usersData = <String, UserData>{};
      
      data.forEach((uid, userData) {
        if (userData is Map) {
          final histories = <HistoryData>[];
          
          final historiesMap = userData['histories'] as Map<dynamic, dynamic>?;
          if (historiesMap != null) {
            historiesMap.forEach((historyId, historyData) {
              if (historyData is Map) {
                histories.add(HistoryData.fromMap(historyData));
              }
            });
          }
          
          // タイムスタンプでソート（新しい順）
          histories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          usersData[uid.toString()] = UserData(
            uid: uid.toString(),
            histories: histories,
          );
        }
      });
      
      setState(() {
        _allUsersData = usersData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの取得に失敗しました: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // デスクトップ版では非対応メッセージを表示
    if (_isDesktop) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理者画面')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '管理者画面はモバイルアプリ\n（Android/iOS）でのみ利用可能です',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Firebase認証が必要なため、\nデスクトップ版では対応していません',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Web版も非対応
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理者画面')),
        body: const Center(
          child: Text('Web版では利用できません'),
        ),
      );
    }
    
    if (!_syncService.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理者画面')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('ログインが必要です'),
              SizedBox(height: 8),
              Text(
                'クラウド同期画面からGoogleでログインしてください',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者画面'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _loadAllUsersData,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'あなたのUID',
            onPressed: () => _showCurrentUid(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllUsersData,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_allUsersData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('まだデータがありません'),
          ],
        ),
      );
    }
    
    return _buildUsersList();
  }
  
  Widget _buildUsersList() {
    final users = _allUsersData.values.toList();
    
    // 総プレイ数でソート
    users.sort((a, b) => b.totalPlays.compareTo(a.totalPlays));
    
    return Column(
      children: [
        // サマリーカード
        _buildSummaryCard(),
        
        // ユーザーリスト
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user, index + 1);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard() {
    final totalUsers = _allUsersData.length;
    final totalPlays = _allUsersData.values.fold<int>(
      0, (sum, user) => sum + user.totalPlays);
    final totalQuestions = _allUsersData.values.fold<int>(
      0, (sum, user) => sum + user.totalQuestions);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('ユーザー数', totalUsers.toString(), Icons.people),
            _buildStatItem('総プレイ数', totalPlays.toString(), Icons.games),
            _buildStatItem('総問題数', totalQuestions.toString(), Icons.quiz),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
  
  Widget _buildUserCard(UserData user, int rank) {
    final avgScore = user.averageScore;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('$rank'),
        ),
        title: Text(
          'ユーザー ${user.uid.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'プレイ数: ${user.totalPlays} | 平均正解率: ${avgScore.toStringAsFixed(1)}%',
        ),
        children: [
          // ジャンル別統計
          if (user.genreStats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ジャンル別統計:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildStatsHeader(),
                  const Divider(height: 8),
                  ...user.genreStats.entries.map((e) => _buildStatsRow(
                    e.key,
                    e.value,
                  )),
                ],
              ),
            ),
          
          // 回答者別統計
          if (user.responderStats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('回答者別統計:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildStatsHeader(),
                  const Divider(height: 8),
                  ...user.responderStats.entries.map((e) => _buildStatsRow(
                    e.key.isEmpty ? '(未設定)' : e.key,
                    e.value,
                  )),
                ],
              ),
            ),
          
          // 最近のプレイ履歴
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('最近のプレイ:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...user.histories.take(5).map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${h.genre} ${h.responderName.isNotEmpty ? "(${h.responderName})" : ""}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${h.score}/${h.total}'),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(h.timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
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
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('名前', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 8),
          const Expanded(flex: 1, child: Text('回数', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          const Expanded(flex: 1, child: Text('正答率', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          const Expanded(flex: 1, child: Text('平均点', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          const Expanded(flex: 1, child: Text('平均時間', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }
  
  Widget _buildStatsRow(String name, GenreStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              '${stats.plays}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              '${stats.averageScore.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              stats.averagePoints.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              stats.formattedAverageTime,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showCurrentUid() {
    final uid = _syncService.currentUser?.uid ?? '不明';
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
            SelectableText(
              uid,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              '※ admin_screen.dart の _adminUid にこのUIDを設定すると、\n他のユーザーはアクセスできなくなります。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
}

/// ユーザーデータモデル
class UserData {
  final String uid;
  final List<HistoryData> histories;
  
  UserData({required this.uid, required this.histories});
  
  int get totalPlays => histories.length;
  
  int get totalQuestions => histories.fold<int>(0, (sum, h) => sum + h.total);
  
  double get averageScore {
    if (histories.isEmpty) return 0;
    final totalScore = histories.fold<int>(0, (sum, h) => sum + h.score);
    final totalQuestions = histories.fold<int>(0, (sum, h) => sum + h.total);
    if (totalQuestions == 0) return 0;
    return (totalScore / totalQuestions) * 100;
  }
  
  Map<String, GenreStats> get genreStats {
    final stats = <String, GenreStats>{};
    for (final h in histories) {
      stats.putIfAbsent(h.genre, () => GenreStats());
      stats[h.genre]!.addHistory(h);
    }
    return stats;
  }
  
  Map<String, GenreStats> get responderStats {
    final stats = <String, GenreStats>{};
    for (final h in histories) {
      final name = h.responderName;
      stats.putIfAbsent(name, () => GenreStats());
      stats[name]!.addHistory(h);
    }
    return stats;
  }
}

class GenreStats {
  int plays = 0;
  int totalScore = 0;
  int totalQuestions = 0;
  int totalTimeMillis = 0;
  
  void addHistory(HistoryData h) {
    plays++;
    totalScore += h.score;
    totalQuestions += h.total;
    totalTimeMillis += h.timeMillis;
  }
  
  double get averageScore {
    if (totalQuestions == 0) return 0;
    return (totalScore / totalQuestions) * 100;
  }
  
  double get averagePoints {
    if (plays == 0) return 0;
    return totalScore / plays;
  }
  
  double get averageTimeSeconds {
    if (plays == 0) return 0;
    return (totalTimeMillis / plays) / 1000;
  }
  
  String get formattedAverageTime {
    final seconds = averageTimeSeconds;
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// 履歴データモデル
class HistoryData {
  final String id;
  final String genre;
  final String responderName;
  final int score;
  final int total;
  final int timeMillis;
  final DateTime timestamp;
  
  HistoryData({
    required this.id,
    required this.genre,
    required this.responderName,
    required this.score,
    required this.total,
    required this.timeMillis,
    required this.timestamp,
  });
  
  factory HistoryData.fromMap(Map<dynamic, dynamic> map) {
    return HistoryData(
      id: map['id'] as String? ?? '',
      genre: map['genre'] as String? ?? '',
      responderName: map['responderName'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      timeMillis: (map['timeMillis'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
