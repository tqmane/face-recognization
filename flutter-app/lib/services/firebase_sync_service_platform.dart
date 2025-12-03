// プラットフォーム判定に基づいたFirebase Sync Service
// このファイルはdart.library.io環境（ネイティブプラットフォーム）で使用される
// しかし、firebase_databaseとgoogle_sign_inはデスクトップでは利用できないため、
// 動的なプラットフォーム判定ではなく、常にスタブをエクスポートする必要がある

// 注意: dart条件付きエクスポートではiOS/Androidとデスクトップを区別できないため、
// pubspec.yamlの依存関係とビルドターゲットで制御する必要がある

// モバイルビルドでのみ使用される
// デスクトップビルドでは firebase_sync_service.dart が stub を直接エクスポートするように変更済み
export 'firebase_sync_service_mobile.dart';
