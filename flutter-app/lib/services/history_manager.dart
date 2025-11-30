import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// クイズの結果を保存するためのクラス
class QuizHistory {
  final String id;
  final String genre;
  final String responderName;
  final int score;
  final int total;
  final int timeMillis;
  final DateTime timestamp;
  final List<QuestionResult> questionResults;

  QuizHistory({
    required this.id,
    required this.genre,
    required this.responderName,
    required this.score,
    required this.total,
    required this.timeMillis,
    required this.timestamp,
    required this.questionResults,
  });

  double get accuracy => total > 0 ? score / total * 100 : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'genre': genre,
    'responderName': responderName,
    'score': score,
    'total': total,
    'timeMillis': timeMillis,
    'timestamp': timestamp.toIso8601String(),
    'questionResults': questionResults.map((q) => q.toJson()).toList(),
  };

  factory QuizHistory.fromJson(Map<String, dynamic> json) => QuizHistory(
    id: json['id'],
    genre: json['genre'],
    responderName: json['responderName'] ?? '',
    score: json['score'],
    total: json['total'],
    timeMillis: json['timeMillis'],
    timestamp: DateTime.parse(json['timestamp']),
    questionResults: (json['questionResults'] as List?)
        ?.map((q) => QuestionResult.fromJson(q))
        .toList() ?? [],
  );
}

/// 各問題の結果
class QuestionResult {
  final int questionNumber;
  final String description;
  final bool isCorrect;
  final bool wasSame; // 正解が「同じ」だったか
  final bool answeredSame; // ユーザーの回答が「同じ」だったか

  QuestionResult({
    required this.questionNumber,
    required this.description,
    required this.isCorrect,
    required this.wasSame,
    required this.answeredSame,
  });

  Map<String, dynamic> toJson() => {
    'questionNumber': questionNumber,
    'description': description,
    'isCorrect': isCorrect,
    'wasSame': wasSame,
    'answeredSame': answeredSame,
  };

  factory QuestionResult.fromJson(Map<String, dynamic> json) => QuestionResult(
    questionNumber: json['questionNumber'],
    description: json['description'],
    isCorrect: json['isCorrect'],
    wasSame: json['wasSame'],
    answeredSame: json['answeredSame'],
  );
}

/// 履歴管理クラス
class HistoryManager {
  static const String _key = 'quiz_history';
  static HistoryManager? _instance;
  
  List<QuizHistory> _histories = [];
  
  static HistoryManager get instance {
    _instance ??= HistoryManager._();
    return _instance!;
  }
  
  HistoryManager._();
  
  List<QuizHistory> get histories => List.unmodifiable(_histories);
  
  /// 履歴を読み込む
  Future<void> loadHistories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _histories = jsonList.map((j) => QuizHistory.fromJson(j)).toList();
      // 新しい順にソート
      _histories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }
  
  /// 履歴を保存
  Future<void> saveHistory(QuizHistory history) async {
    _histories.insert(0, history);
    await _persist();
  }
  
  /// 永続化
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_histories.map((h) => h.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
  
  /// 履歴をクリア
  Future<void> clearHistories() async {
    _histories.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
  
  /// 指定したIDの履歴を削除
  Future<void> deleteHistory(String id) async {
    _histories.removeWhere((h) => h.id == id);
    await _persist();
  }
  
  /// 指定した複数のIDの履歴を削除
  Future<void> deleteHistories(Set<String> ids) async {
    _histories.removeWhere((h) => ids.contains(h.id));
    await _persist();
  }
  
  /// ジャンルごとの統計
  Map<String, GenreStats> getStatsByGenre() {
    final Map<String, List<QuizHistory>> grouped = {};
    for (final h in _histories) {
      grouped.putIfAbsent(h.genre, () => []).add(h);
    }
    
    return grouped.map((genre, histories) => MapEntry(
      genre,
      GenreStats.fromHistories(genre, histories),
    ));
  }
  
  /// 全体の統計
  GenreStats getOverallStats() {
    return GenreStats.fromHistories('全体', _histories);
  }
  
  /// 回答者ごとの統計
  Map<String, GenreStats> getStatsByResponder() {
    final Map<String, List<QuizHistory>> grouped = {};
    for (final h in _histories) {
      final name = h.responderName.isEmpty ? '匿名' : h.responderName;
      grouped.putIfAbsent(name, () => []).add(h);
    }
    
    return grouped.map((name, histories) => MapEntry(
      name,
      GenreStats.fromHistories(name, histories),
    ));
  }
  
  /// ユニークな回答者リスト
  List<String> getResponders() {
    final set = <String>{};
    for (final h in _histories) {
      set.add(h.responderName.isEmpty ? '匿名' : h.responderName);
    }
    return set.toList()..sort();
  }
}

/// ジャンル/回答者ごとの統計
class GenreStats {
  final String name;
  final int totalTests;
  final int totalQuestions;
  final int totalCorrect;
  final int totalTimeMillis;
  final double averageAccuracy;
  final double averageScore;
  final double averageTime;

  GenreStats({
    required this.name,
    required this.totalTests,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalTimeMillis,
    required this.averageAccuracy,
    required this.averageScore,
    required this.averageTime,
  });

  factory GenreStats.fromHistories(String name, List<QuizHistory> histories) {
    if (histories.isEmpty) {
      return GenreStats(
        name: name,
        totalTests: 0,
        totalQuestions: 0,
        totalCorrect: 0,
        totalTimeMillis: 0,
        averageAccuracy: 0,
        averageScore: 0,
        averageTime: 0,
      );
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalTimeMillis = 0;

    for (final h in histories) {
      totalQuestions += h.total;
      totalCorrect += h.score;
      totalTimeMillis += h.timeMillis;
    }

    return GenreStats(
      name: name,
      totalTests: histories.length,
      totalQuestions: totalQuestions,
      totalCorrect: totalCorrect,
      totalTimeMillis: totalTimeMillis,
      averageAccuracy: totalQuestions > 0 ? totalCorrect / totalQuestions * 100 : 0,
      averageScore: totalCorrect / histories.length,
      averageTime: totalTimeMillis / histories.length,
    );
  }
}
