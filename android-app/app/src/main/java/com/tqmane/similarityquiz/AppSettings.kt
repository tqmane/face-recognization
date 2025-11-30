package com.tqmane.similarityquiz

import android.content.Context
import android.content.SharedPreferences

/**
 * アプリ設定を管理するシングルトン
 */
class AppSettings private constructor(context: Context) {
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    companion object {
        private const val PREFS_NAME = "app_settings"
        
        // キー
        private const val KEY_PARALLEL_DOWNLOADS = "parallel_downloads"
        private const val KEY_CACHE_SIZE = "cache_size"
        private const val KEY_DOWNLOAD_TIMEOUT = "download_timeout"
        private const val KEY_TARGET_IMAGE_SIZE = "target_image_size"
        private const val KEY_USE_RELIABLE_SOURCES_FIRST = "use_reliable_sources_first"
        
        // デフォルト値
        const val DEFAULT_PARALLEL_DOWNLOADS = 2
        const val DEFAULT_CACHE_SIZE = 20
        const val DEFAULT_DOWNLOAD_TIMEOUT = 10
        const val DEFAULT_TARGET_IMAGE_SIZE = 800
        const val DEFAULT_USE_RELIABLE_SOURCES_FIRST = true
        
        @Volatile
        private var instance: AppSettings? = null
        
        fun getInstance(context: Context): AppSettings {
            return instance ?: synchronized(this) {
                instance ?: AppSettings(context.applicationContext).also { instance = it }
            }
        }
    }
    
    /**
     * 並列ダウンロード数（1-10）
     */
    var parallelDownloads: Int
        get() = prefs.getInt(KEY_PARALLEL_DOWNLOADS, DEFAULT_PARALLEL_DOWNLOADS)
        set(value) = prefs.edit().putInt(KEY_PARALLEL_DOWNLOADS, value.coerceIn(1, 10)).apply()
    
    /**
     * キャッシュサイズ（5-100）
     */
    var cacheSize: Int
        get() = prefs.getInt(KEY_CACHE_SIZE, DEFAULT_CACHE_SIZE)
        set(value) = prefs.edit().putInt(KEY_CACHE_SIZE, value.coerceIn(5, 100)).apply()
    
    /**
     * ダウンロードタイムアウト秒数（5-60）
     */
    var downloadTimeout: Int
        get() = prefs.getInt(KEY_DOWNLOAD_TIMEOUT, DEFAULT_DOWNLOAD_TIMEOUT)
        set(value) = prefs.edit().putInt(KEY_DOWNLOAD_TIMEOUT, value.coerceIn(5, 60)).apply()
    
    /**
     * 目標画像サイズ（400-1600）
     */
    var targetImageSize: Int
        get() = prefs.getInt(KEY_TARGET_IMAGE_SIZE, DEFAULT_TARGET_IMAGE_SIZE)
        set(value) = prefs.edit().putInt(KEY_TARGET_IMAGE_SIZE, value.coerceIn(400, 1600)).apply()
    
    /**
     * 信頼性の高いソースを優先するか
     */
    var useReliableSourcesFirst: Boolean
        get() = prefs.getBoolean(KEY_USE_RELIABLE_SOURCES_FIRST, DEFAULT_USE_RELIABLE_SOURCES_FIRST)
        set(value) = prefs.edit().putBoolean(KEY_USE_RELIABLE_SOURCES_FIRST, value).apply()
    
    /**
     * すべての設定をデフォルトにリセット
     */
    fun resetToDefaults() {
        prefs.edit().apply {
            putInt(KEY_PARALLEL_DOWNLOADS, DEFAULT_PARALLEL_DOWNLOADS)
            putInt(KEY_CACHE_SIZE, DEFAULT_CACHE_SIZE)
            putInt(KEY_DOWNLOAD_TIMEOUT, DEFAULT_DOWNLOAD_TIMEOUT)
            putInt(KEY_TARGET_IMAGE_SIZE, DEFAULT_TARGET_IMAGE_SIZE)
            putBoolean(KEY_USE_RELIABLE_SOURCES_FIRST, DEFAULT_USE_RELIABLE_SOURCES_FIRST)
            apply()
        }
    }
}
