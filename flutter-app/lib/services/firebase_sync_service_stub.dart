import 'dart:async';
import 'history_manager.dart';

/// ダミーのユーザークラス（デスクトップ用）
class StubUser {
  final String uid;
  final String? displayName;
  final String? email;
  
  StubUser({required this.uid, this.displayName, this.email});
}

/// Firebase非対応プラットフォーム用のスタブ実装
class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  static FirebaseSyncService get instance => _instance;
  
  FirebaseSyncService._internal();

  Future<void> ensureInitialized() async {}
  
  // 常にサインアウト状態
  bool get isSignedIn => false;
  
  // ユーザー情報（常にnull）
  StubUser? get currentUser => null;
  String? get userDisplayName => null;
  String? get userEmail => null;
  
  /// 認証状態の変更を監視（常にnull）
  Stream<dynamic> get authStateChanges => Stream.value(null);
  
  /// サインイン（デスクトップでは無効）
  Future<dynamic> signInWithGoogle() async {
    print('Firebase is not supported on this platform');
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
