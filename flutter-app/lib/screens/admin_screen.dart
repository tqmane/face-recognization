// プラットフォームに応じて適切な実装をエクスポート
// iOS/Android -> モバイル実装（Firebase対応）
// Web/デスクトップ -> スタブ実装

export 'admin_screen_mobile.dart'
    if (dart.library.js_interop) 'admin_screen_stub.dart';
