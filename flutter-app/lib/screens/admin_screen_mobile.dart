import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_sync_service.dart';
import '../services/firebase_init.dart';

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
    if (!_isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_accounts, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'アクセス権限がありません',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '管理者UID: $_adminUid',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'あなたのUID: ${_syncService.currentUser?.uid ?? "不明"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('全ユーザーデータを読み込み中...'),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
            Text('ユーザーデータがありません'),
          ],
        ),
      );
    }
    
    // ユーザー一覧を表示（プレイ回数順）
    final sortedUsers = _allUsersData.values.toList()
      ..sort((a, b) => b.totalPlays.compareTo(a.totalPlays));
    
    return RefreshIndicator(
      onRefresh: _loadAllUsersData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedUsers.length,
        itemBuilder: (context, index) => _buildUserCard(sortedUsers[index]),
      ),
    );
  }
  
  Widget _buildUserCard(UserData user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: user.uid == _adminUid ? Colors.amber : Colors.blue,
          child: Text(
            user.uid.substring(0, 2).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.uid.length > 12 ? '${user.uid.substring(0, 12)}...' : user.uid,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            if (user.uid == _adminUid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'プレイ回数: ${user.totalPlays} | 平均正答率: ${user.averageScore.toStringAsFixed(1)}%',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // UID全表示
                Row(
                  children: [
                    const Text('UID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: SelectableText(
                        user.uid,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                
                // ジャンル別統計
                if (user.genreStats.isNotEmpty) ...[
                  const Text('📊 ジャンル別統計:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...user.genreStats.entries.map((e) => _buildStatRow(e.key, e.value)),
                  const Divider(),
                ],
                
                // 回答者別統計
                if (user.responderStats.isNotEmpty) ...[
                  const Text('👤 回答者別統計:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...user.responderStats.entries.map((e) => _buildStatRow(e.key, e.value)),
                  const Divider(),
                ],
                
                // 最近の履歴
                const Text('📜 最近の履歴:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...user.histories.take(5).map((h) => _buildHistoryItem(h)),
                if (user.histories.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... 他 ${user.histories.length - 5} 件',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, GenreStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'テスト: ${stats.plays}回 | 正答率: ${stats.averageScore.toStringAsFixed(1)}% | 平均: ${stats.averagePoints.toStringAsFixed(1)}点 | 時間: ${stats.formattedAverageTime}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryItem(HistoryData history) {
    final date = '${history.timestamp.year}/${history.timestamp.month}/${history.timestamp.day}';
    final time = '${history.timestamp.hour}:${history.timestamp.minute.toString().padLeft(2, '0')}';
    final percent = history.total > 0 ? (history.score / history.total * 100).toStringAsFixed(0) : '0';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$date $time',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${history.genre} (${history.responderName})',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${history.score}/${history.total} ($percent%)',
            style: const TextStyle(fontSize: 13),
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
