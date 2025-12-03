import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ダウンロード進捗通知を管理するサービス
class DownloadNotificationService {
  static final DownloadNotificationService _instance = DownloadNotificationService._internal();
  static DownloadNotificationService get instance => _instance;
  
  DownloadNotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  static const String _channelId = 'download_progress';
  static const String _channelName = 'ダウンロード進捗';
  static const int _notificationId = 1001;
  
  /// 通知サービスを初期化
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return; // Webでは通知非対応
    
    try {
      // Android設定
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS/macOS設定
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      // Linux設定
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      
      final settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );
      
      await _notifications.initialize(settings);
      _isInitialized = true;
    } catch (e) {
      print('通知の初期化に失敗: $e');
    }
  }
  
  /// 通知権限をリクエスト（Android 13以上、iOS）
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    
    try {
      if (Platform.isAndroid) {
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          final granted = await android.requestNotificationsPermission();
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final ios = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (ios != null) {
          final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: false,
          );
          return granted ?? false;
        }
      }
      return true; // その他のプラットフォームは権限不要
    } catch (e) {
      print('通知権限リクエストに失敗: $e');
      return false;
    }
  }
  
  /// ダウンロード開始通知を表示
  Future<void> showDownloadStarted(String genreName, int totalQuestions) async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'テストセットのダウンロード進捗を表示します',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        showProgress: true,
        maxProgress: totalQuestions,
        progress: 0,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.progress,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await _notifications.show(
        _notificationId,
        '📦 $genreName をダウンロード中',
        '準備中...',
        details,
      );
    } catch (e) {
      print('通知表示に失敗: $e');
    }
  }
  
  /// ダウンロード進捗を更新
  Future<void> updateProgress(String genreName, int current, int total) async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      final percent = (current * 100) ~/ total;
      
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'テストセットのダウンロード進捗を表示します',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        showProgress: true,
        maxProgress: total,
        progress: current,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.progress,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await _notifications.show(
        _notificationId,
        '📦 $genreName をダウンロード中',
        '$current / $total 問 ($percent%)',
        details,
      );
    } catch (e) {
      // エラーは無視（通知は補助的機能）
    }
  }
  
  /// ダウンロード完了通知を表示
  Future<void> showDownloadComplete(String genreName, int totalQuestions) async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'テストセットのダウンロード進捗を表示します',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await _notifications.show(
        _notificationId,
        '✅ $genreName のダウンロード完了',
        '$totalQuestions 問を保存しました',
        details,
      );
    } catch (e) {
      print('完了通知の表示に失敗: $e');
    }
  }
  
  /// ダウンロード失敗通知を表示
  Future<void> showDownloadFailed(String genreName, String reason) async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'テストセットのダウンロード進捗を表示します',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await _notifications.show(
        _notificationId,
        '❌ $genreName のダウンロード失敗',
        reason,
        details,
      );
    } catch (e) {
      print('失敗通知の表示に失敗: $e');
    }
  }
  
  /// ダウンロードキャンセル通知を表示
  Future<void> showDownloadCanceled(String genreName) async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'テストセットのダウンロード進捗を表示します',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: false,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await _notifications.show(
        _notificationId,
        '🚫 $genreName のダウンロードをキャンセル',
        'ダウンロードを中止しました',
        details,
      );
    } catch (e) {
      print('キャンセル通知の表示に失敗: $e');
    }
  }
  
  /// 通知を消去
  Future<void> cancelNotification() async {
    if (!_isInitialized || kIsWeb) return;
    
    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      // エラーは無視
    }
  }
}
