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

bool get _isMobile {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

/// Firebase初期化
Future<void> initializeFirebase() async {
  if (!_isMobile) {
    print('Firebase is not supported on desktop platforms');
    return;
  }
  
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
}
