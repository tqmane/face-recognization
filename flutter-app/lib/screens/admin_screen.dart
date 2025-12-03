// プラットフォームに応じて適切な実装をエクスポート
// デスクトップ（Windows/macOS/Linux）ではスタブを使用
// モバイル（Android/iOS）では実際のFirebase実装を使用
export 'admin_screen_stub.dart'
    if (dart.library.io) 'admin_screen_platform.dart';

