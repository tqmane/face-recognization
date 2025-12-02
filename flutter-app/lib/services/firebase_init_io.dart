// Firebase初期化 - IO版（モバイル・デスクトップ用）
// 
// デスクトップビルド時:
//   CI で pubspec.yaml から firebase_core が削除されるため、
//   このファイルの Firebase インポートはエラーになる
//   → CIで firebase_init_desktop.dart に置き換える
// 
// モバイルビルド時:
//   firebase_core が存在するため正常に動作

import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

bool get _isMobile {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

/// Firebaseが正常に初期化されたかどうか
bool _firebaseInitialized = false;

/// Firebaseが初期化済みかどうかを返す
bool get isFirebaseInitialized => _firebaseInitialized;

/// Firebase初期化
Future<bool> initializeFirebase() async {
  if (!_isMobile) {
    print('Firebase is not supported on desktop platforms');
    _firebaseInitialized = false;
    return false;
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
    print('Firebase initialized successfully');
    return true;
  } catch (e) {
    _firebaseInitialized = false;
    print('Firebase initialization failed: $e');
    return false;
  }
}
