import 'dart:io' show Platform;
import 'dart:async';
import 'history_manager.dart';

// 動的にFirebase実装を使用するかどうかを判定
bool get _shouldUseFirebase {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

/// プラットフォーム判定に基づいたFirebase Sync Service
/// デスクトップではスタブとして動作
class FirebaseSyncService {
  static FirebaseSyncService? _instance;
  static FirebaseSyncService get instance {
    _instance ??= FirebaseSyncService._internal();
    return _instance!;
  }
  
  FirebaseSyncService._internal();
  
  // プラットフォーム判定
  static bool get isMobilePlatform => _shouldUseFirebase;
  
  // デスクトップでは常にサインアウト状態
  bool get isSignedIn => false;
  
  // ユーザー情報（デスクトップでは常にnull）
  String? get userDisplayName => null;
  String? get userEmail => null;
  
  /// 認証状態の変更を監視（常にnull）
  Stream<dynamic> get authStateChanges => Stream.value(null);
  
  /// サインイン（デスクトップでは無効）
  Future<dynamic> signInWithGoogle() async {
    print('Firebase is not supported on desktop platforms (Windows/macOS/Linux)');
    return null;
  }
  
  /// サインアウト
  Future<void> signOut() async {}
  
  /// リアルタイム同期をセットアップ（何もしない）
  void setupRealtimeSync() {}
  
  /// リアルタイム同期を停止
  void stopRealtimeSync() {}
  
  /// 履歴アップロード（常に失敗）
  Future<bool> uploadHistory(QuizHistory history) async => false;
  
  /// 全履歴アップロード
  Future<int> uploadAllHistories() async => 0;
  
  /// 履歴削除
  Future<bool> deleteHistoryFromFirebase(String historyId) async => false;
  
  /// 全履歴削除
  Future<bool> clearFirebaseHistories() async => false;
}
