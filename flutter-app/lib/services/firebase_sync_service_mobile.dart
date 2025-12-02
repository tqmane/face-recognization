import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'history_manager.dart';

/// Firebase Realtime Database との同期を管理するクラス
class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  static FirebaseSyncService get instance => _instance;
  
  FirebaseSyncService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;
  
  // iOS用のClient ID（GoogleService-Info.plistから）
  static const String _iosClientId = '991042237694-8p0oehun6n5i50dil6apqqdh5d0u14e6.apps.googleusercontent.com';
  // Android用のWeb Client ID（Firebase Consoleから）
  static const String _webClientId = '991042237694-ij0b64qvl4llhf8e3dkk86mdpsc59snj.apps.googleusercontent.com';
  
  StreamSubscription<DatabaseEvent>? _syncSubscription;
  
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  
  /// ユーザー表示名を取得
  String? get userDisplayName => currentUser?.displayName;
  
  /// ユーザーメールアドレスを取得
  String? get userEmail => currentUser?.email;
  
  /// 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// GoogleSignInを初期化
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      // iOSとAndroidで異なる設定
      if (Platform.isIOS) {
        await _googleSignIn.initialize(
          clientId: _iosClientId,
          serverClientId: _webClientId,
        );
      } else {
        await _googleSignIn.initialize(
          serverClientId: _webClientId,
        );
      }
      _googleSignInInitialized = true;
    }
  }
  
  /// Google認証でサインイン
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();
      
      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // サインイン後、リアルタイム同期を開始
      setupRealtimeSync();
      
      return userCredential.user;
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
  }
  
  /// サインアウト
  Future<void> signOut() async {
    stopRealtimeSync();
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      // disconnect may fail if not signed in
    }
    await _auth.signOut();
  }
  
  /// リアルタイム同期をセットアップ
  void setupRealtimeSync() {
    final user = currentUser;
    if (user == null) return;
    
    final ref = _database.ref('users/${user.uid}/histories');
    
    _syncSubscription?.cancel();
    _syncSubscription = ref.onValue.listen((event) {
      _handleRemoteDataChange(event.snapshot);
    });
    
    print('Realtime sync started for user: ${user.uid}');
  }
  
  /// リアルタイム同期を停止
  void stopRealtimeSync() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }
  
  /// リモートデータの変更を処理
  void _handleRemoteDataChange(DataSnapshot snapshot) {
    if (!snapshot.exists) return;
    
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;
    
    final remoteHistories = <QuizHistory>[];
    
    data.forEach((key, value) {
      try {
        final history = _parseHistoryFromFirebase(value as Map<dynamic, dynamic>);
        remoteHistories.add(history);
      } catch (e) {
        print('Error parsing history: $e');
      }
    });
    
    // ローカルデータとマージ
    _mergeHistories(remoteHistories);
  }
  
  /// Firebaseのデータをパース
  QuizHistory _parseHistoryFromFirebase(Map<dynamic, dynamic> map) {
    final questionResults = (map['questionResults'] as List<dynamic>?)?.map((qr) {
      final qrMap = qr as Map<dynamic, dynamic>;
      return QuestionResult(
        questionNumber: (qrMap['questionNumber'] as num?)?.toInt() ?? 0,
        description: qrMap['description'] as String? ?? '',
        isCorrect: qrMap['isCorrect'] as bool? ?? false,
        wasSame: qrMap['wasSame'] as bool? ?? false,
        answeredSame: qrMap['answeredSame'] as bool? ?? false,
      );
    }).toList() ?? [];
    
    return QuizHistory(
      id: map['id'] as String? ?? '',
      genre: map['genre'] as String? ?? '',
      responderName: map['responderName'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      timeMillis: (map['timeMillis'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
      questionResults: questionResults,
    );
  }
  
  /// ローカルとリモートの履歴をマージ
  void _mergeHistories(List<QuizHistory> remoteHistories) {
    final localHistories = HistoryManager.instance.histories;
    final localIds = localHistories.map((h) => h.id).toSet();
    
    // リモートにあってローカルにないものを追加
    final newFromRemote = remoteHistories.where((h) => !localIds.contains(h.id)).toList();
    
    for (final history in newFromRemote) {
      HistoryManager.instance.saveHistory(history);
    }
    
    if (newFromRemote.isNotEmpty) {
      print('Added ${newFromRemote.length} histories from remote');
    }
  }
  
  /// ローカルの履歴をFirebaseにアップロード
  Future<bool> uploadHistory(QuizHistory history) async {
    final user = currentUser;
    if (user == null) return false;
    
    try {
      final ref = _database.ref('users/${user.uid}/histories/${history.id}');
      
      await ref.set({
        'id': history.id,
        'genre': history.genre,
        'responderName': history.responderName,
        'score': history.score,
        'total': history.total,
        'timeMillis': history.timeMillis,
        'timestamp': history.timestamp.millisecondsSinceEpoch,
        'questionResults': history.questionResults.map((qr) => {
          'questionNumber': qr.questionNumber,
          'description': qr.description,
          'isCorrect': qr.isCorrect,
          'wasSame': qr.wasSame,
          'answeredSame': qr.answeredSame,
        }).toList(),
      });
      
      print('History uploaded: ${history.id}');
      return true;
    } catch (e) {
      print('Upload failed: $e');
      return false;
    }
  }
  
  /// 全てのローカル履歴をアップロード
  Future<int> uploadAllHistories() async {
    final user = currentUser;
    if (user == null) return 0;
    
    final histories = HistoryManager.instance.histories;
    int uploadedCount = 0;
    
    for (final history in histories) {
      if (await uploadHistory(history)) {
        uploadedCount++;
      }
    }
    
    print('Uploaded $uploadedCount histories');
    return uploadedCount;
  }
  
  /// Firebaseから履歴を削除
  Future<bool> deleteHistoryFromFirebase(String historyId) async {
    final user = currentUser;
    if (user == null) return false;
    
    try {
      await _database.ref('users/${user.uid}/histories/$historyId').remove();
      print('History deleted from Firebase: $historyId');
      return true;
    } catch (e) {
      print('Delete failed: $e');
      return false;
    }
  }
  
  /// Firebaseから全履歴を削除
  Future<bool> clearFirebaseHistories() async {
    final user = currentUser;
    if (user == null) return false;
    
    try {
      await _database.ref('users/${user.uid}/histories').remove();
      print('All histories cleared from Firebase');
      return true;
    } catch (e) {
      print('Clear failed: $e');
      return false;
    }
  }
}
