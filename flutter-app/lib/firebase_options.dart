// Firebase設定 - flutter fire configureで自動生成されるファイルの代わり
// 
// このファイルはgoogle-services.jsonとGoogleService-Info.plistから
// 手動で作成されています。

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// デフォルトのFirebase設定
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android設定（google-services.jsonから抽出）
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0p0VVhW_yeemr9cWwdcDOd-BOSI3hk4Q',
    appId: '1:991042237694:android:8ed36d62ff99488f3161af',
    messagingSenderId: '991042237694',
    projectId: 'similarity-quiz-sync',
    databaseURL: 'https://similarity-quiz-sync-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'similarity-quiz-sync.firebasestorage.app',
  );

  // iOS設定（GoogleService-Info.plistから抽出）
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCptsqivcPQbeZ9cDKcpV_n8Tfc_x8x1No',
    appId: '1:991042237694:ios:2e3f9a6d05f4e9a63161af',
    messagingSenderId: '991042237694',
    projectId: 'similarity-quiz-sync',
    databaseURL: 'https://similarity-quiz-sync-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'similarity-quiz-sync.firebasestorage.app',
    iosBundleId: 'com.tqmane.similarityQuiz',
  );
}
