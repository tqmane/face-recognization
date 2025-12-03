// プラットフォームに応じて適切な実装をエクスポート
// iOS/Android -> モバイル実装（Firebase対応）
// Web/デスクトップ -> スタブ実装
//
// 注意: CIワークフローでデスクトップビルド時は
// admin_screen_stub.dartをadmin_screen_mobile.dartにコピーする
export 'admin_screen_stub.dart'
    if (dart.library.io) 'admin_screen_mobile.dart';
