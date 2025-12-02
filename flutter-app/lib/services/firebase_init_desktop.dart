// Firebase初期化 - デスクトップ版（スタブ）
// デスクトップビルド時にCIでfirebase_init_io.dartを
// このファイルの内容に置き換える

/// Firebaseが初期化済みかどうかを返す
bool get isFirebaseInitialized => false;

/// Firebase初期化（デスクトップでは何もしない）
Future<bool> initializeFirebase() async {
  print('Firebase is not supported on desktop platforms');
  return false;
}
