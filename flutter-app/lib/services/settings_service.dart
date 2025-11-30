import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ設定を管理するサービス
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;
  
  SettingsService._internal();
  
  SharedPreferences? _prefs;
  
  // デフォルト値
  static const int defaultParallelDownloads = 2;
  static const int defaultCacheSize = 20;
  static const int defaultDownloadTimeout = 10;
  static const int defaultTargetImageSize = 800;
  static const bool defaultUseReliableSourcesFirst = true;
  
  // 設定キー
  static const String _keyParallelDownloads = 'parallel_downloads';
  static const String _keyCacheSize = 'cache_size';
  static const String _keyDownloadTimeout = 'download_timeout';
  static const String _keyTargetImageSize = 'target_image_size';
  static const String _keyUseReliableSourcesFirst = 'use_reliable_sources_first';
  
  /// 初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 並列ダウンロード数（1-10）
  int get parallelDownloads {
    return _prefs?.getInt(_keyParallelDownloads) ?? defaultParallelDownloads;
  }
  
  set parallelDownloads(int value) {
    _prefs?.setInt(_keyParallelDownloads, value.clamp(1, 10));
  }
  
  /// キャッシュサイズ（5-100）
  int get cacheSize {
    return _prefs?.getInt(_keyCacheSize) ?? defaultCacheSize;
  }
  
  set cacheSize(int value) {
    _prefs?.setInt(_keyCacheSize, value.clamp(5, 100));
  }
  
  /// ダウンロードタイムアウト秒数（5-60）
  int get downloadTimeout {
    return _prefs?.getInt(_keyDownloadTimeout) ?? defaultDownloadTimeout;
  }
  
  set downloadTimeout(int value) {
    _prefs?.setInt(_keyDownloadTimeout, value.clamp(5, 60));
  }
  
  /// 目標画像サイズ（400-1600）
  int get targetImageSize {
    return _prefs?.getInt(_keyTargetImageSize) ?? defaultTargetImageSize;
  }
  
  set targetImageSize(int value) {
    _prefs?.setInt(_keyTargetImageSize, value.clamp(400, 1600));
  }
  
  /// 信頼性の高いソースを優先するか
  bool get useReliableSourcesFirst {
    return _prefs?.getBool(_keyUseReliableSourcesFirst) ?? defaultUseReliableSourcesFirst;
  }
  
  set useReliableSourcesFirst(bool value) {
    _prefs?.setBool(_keyUseReliableSourcesFirst, value);
  }
  
  /// すべての設定をデフォルトにリセット
  Future<void> resetToDefaults() async {
    parallelDownloads = defaultParallelDownloads;
    cacheSize = defaultCacheSize;
    downloadTimeout = defaultDownloadTimeout;
    targetImageSize = defaultTargetImageSize;
    useReliableSourcesFirst = defaultUseReliableSourcesFirst;
  }
  
  /// 設定のサマリーを取得
  Map<String, dynamic> toMap() {
    return {
      'parallelDownloads': parallelDownloads,
      'cacheSize': cacheSize,
      'downloadTimeout': downloadTimeout,
      'targetImageSize': targetImageSize,
      'useReliableSourcesFirst': useReliableSourcesFirst,
    };
  }
}
