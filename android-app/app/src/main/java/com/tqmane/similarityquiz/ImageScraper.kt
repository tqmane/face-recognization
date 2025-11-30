package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.jsoup.Jsoup
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * 超高速画像スクレイピングクラス
 * OkHttpによる高性能ネットワーク処理
 */
class ImageScraper {

    companion object {
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        private const val BING_URL = "https://www.bing.com/images/search"
        private const val JSOUP_TIMEOUT = 10000  // 10秒（Jsoup用）
        
        private const val TARGET_HEIGHT = 450
        private const val MAX_WIDTH = 550
        
        // 除外キーワード（強化版）
        private val EXCLUDE_KEYWORDS = listOf(
            "AI generated", "イラスト", "illustration", "drawing",
            "anime", "アニメ", "manga", "漫画", "cartoon", "sketch",
            "vector", "clip art", "clipart", "icon", "logo",
            "render", "3d", "cg", "digital art", "fanart"
        )
        
        // 除外ドメイン（イラスト・素材系）
        private val EXCLUDE_DOMAINS = listOf(
            "deviantart.com", "pixiv.net", "artstation.com",
            "dreamstime.com", "shutterstock.com", "istockphoto.com",
            "freepik.com", "flaticon.com", "vectorstock.com",
            "pngtree.com", "cleanpng.com", "pngwing.com",
            "pinterest.com", "tumblr.com"
        )
        
        // ランダムオフセットの範囲（多様性向上）
        private val RANDOM_OFFSETS = listOf(1, 35, 70, 105, 140)
    }

    // OkHttpクライアント（シングルトン、接続プール使用）
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    // スレッドセーフなキャッシュ
    private val urlCache = ConcurrentHashMap<String, MutableList<String>>()
    
    // 使用済みURL（クイズセッション全体で重複防止）
    private val usedUrls = ConcurrentHashMap.newKeySet<String>()
    
    // 現在の問題で選択中のURL（同一問題内での重複防止）
    private val currentQuestionUrls = ConcurrentHashMap.newKeySet<String>()
    
    // プリフェッチ済み画像キャッシュ
    private val imageCache = ConcurrentHashMap<String, Bitmap>()

    /**
     * 検索クエリから画像URLリストを取得
     */
    suspend fun searchImages(query: String, maxResults: Int = 30): List<String> = withContext(Dispatchers.IO) {
        val searchStartTime = System.currentTimeMillis()
        
        // キャッシュから未使用のURLを取得
        urlCache[query]?.let { cached ->
            val unused = cached.filter { it !in usedUrls && it !in currentQuestionUrls }
            if (unused.size >= maxResults) {
                android.util.Log.d("ImageScraper", "Cache hit for '$query': ${unused.size} URLs")
                return@withContext unused.take(maxResults)
            }
        }

        val imageUrls = mutableListOf<String>()
        
        try {
            // ランダムなオフセットで多様な結果を取得
            val randomOffset = RANDOM_OFFSETS.random()
            // 写真フィルタのみ使用（除外キーワードはドメインチェックで対応）
            val searchUrl = "$BING_URL?q=${query.replace(" ", "+")}&form=HDRSC2&first=$randomOffset&count=100&qft=+filterui:photo-photo"
            
            val jsoupStartTime = System.currentTimeMillis()
            val doc = Jsoup.connect(searchUrl)
                .userAgent(USER_AGENT)
                .timeout(JSOUP_TIMEOUT)
                .get()
            android.util.Log.d("ImageScraper", "Jsoup search took ${System.currentTimeMillis() - jsoupStartTime}ms for '$query'")
            
            val images = doc.select("a.iusc")
            
            for (element in images) {
                if (imageUrls.size >= 50) break
                
                try {
                    val dataM = element.attr("m")
                    if (dataM.isNotEmpty()) {
                        val murlMatch = Regex("\"murl\":\"([^\"]+)\"").find(dataM)
                        murlMatch?.groupValues?.get(1)?.let { url ->
                            // タイトル・説明から除外キーワードチェック
                            val descMatch = Regex("\"desc\":\"([^\"]+)\"").find(dataM)
                            val desc = descMatch?.groupValues?.get(1)?.lowercase() ?: ""
                            val hasExcludedKeyword = EXCLUDE_KEYWORDS.any { keyword ->
                                desc.contains(keyword.lowercase())
                            }
                            
                            // 除外ドメインをチェック
                            val isExcludedDomain = EXCLUDE_DOMAINS.any { domain -> 
                                url.lowercase().contains(domain) 
                            }
                            
                            if (url.startsWith("http") && isImageUrl(url) && 
                                url !in usedUrls && url !in currentQuestionUrls &&
                                !isExcludedDomain && !hasExcludedKeyword) {
                                imageUrls.add(url)
                            }
                        }
                    }
                } catch (e: Exception) {
                    continue
                }
            }
            
            if (imageUrls.isNotEmpty()) {
                val existing = urlCache.getOrPut(query) { mutableListOf() }
                synchronized(existing) {
                    imageUrls.forEach { url ->
                        if (url !in existing) existing.add(url)
                    }
                }
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        imageUrls.filter { it !in usedUrls && it !in currentQuestionUrls }.take(maxResults)
    }

    /**
     * URLから画像をダウンロード（OkHttp使用・高性能版）
     */
    private suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
        // 既に使用済みならスキップ
        if (imageUrl in usedUrls) return@withContext null
        
        // キャッシュチェック（recycled確認）
        imageCache[imageUrl]?.let { cached ->
            if (!cached.isRecycled) return@withContext cached
            imageCache.remove(imageUrl)
        }
        
        try {
            val request = Request.Builder()
                .url(imageUrl)
                .header("User-Agent", USER_AGENT)
                .build()
            
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                
                val bytes = response.body?.bytes() ?: return@withContext null
                
                // BitmapFactory.Optionsでメモリ効率化
                val options = BitmapFactory.Options().apply {
                    inPreferredConfig = Bitmap.Config.RGB_565  // メモリ半減
                    inSampleSize = 1
                }
                
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                
                // キャッシュに保存（サイズ制限）
                if (bitmap != null && imageCache.size < 50) {
                    imageCache[imageUrl] = bitmap
                }
                bitmap
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 複数URLから並列で最速ダウンロード（指定されたURLのみを使用）
     */
    private suspend fun downloadRace(urls: List<String>, markAsUsed: Boolean = true): Pair<Bitmap?, String?> = withContext(Dispatchers.IO) {
        val raceStartTime = System.currentTimeMillis()
        if (urls.isEmpty()) return@withContext Pair(null, null)
        
        // 使用済みURLを除外
        val availableUrls = urls.filter { it !in usedUrls && it !in currentQuestionUrls }
        if (availableUrls.isEmpty()) {
            android.util.Log.w("ImageScraper", "No available URLs for download race")
            return@withContext Pair(null, null)
        }
        
        // 最大5つを並列ダウンロード（競争）
        val result = CompletableDeferred<Pair<Bitmap?, String?>>()
        val jobs = mutableListOf<Job>()
        
        availableUrls.take(5).forEach { url ->
            val job = launch {
                val bitmap = downloadImage(url)
                if (bitmap != null && result.isActive) {
                    if (result.complete(Pair(bitmap, url))) {
                        if (markAsUsed) {
                            usedUrls.add(url)
                        }
                        currentQuestionUrls.add(url)
                    }
                }
            }
            jobs.add(job)
        }
        
        // タイムアウト付きで待機
        val winner = withTimeoutOrNull(4000) {
            result.await()
        }
        
        // 残りのジョブをキャンセル
        jobs.forEach { it.cancel() }
        
        val raceTime = System.currentTimeMillis() - raceStartTime
        if (winner == null) {
            android.util.Log.w("ImageScraper", "Download race timed out after ${raceTime}ms")
        } else {
            android.util.Log.d("ImageScraper", "Download race won in ${raceTime}ms")
        }
        
        winner ?: Pair(null, null)
    }

    /**
     * 2つの検索クエリから画像を取得して合成（超高速版）
     */
    suspend fun createComparisonImage(query1: String, query2: String): Bitmap? = withContext(Dispatchers.IO) {
        // 現在の問題用のURL追跡をクリア
        currentQuestionUrls.clear()
        
        try {
            // 並列で検索開始
            val urls1Deferred = async { searchImages(query1) }
            val urls2Deferred = async { searchImages(query2) }
            
            val urls1 = urls1Deferred.await()
            val urls2 = urls2Deferred.await()
            
            if (urls1.isEmpty() || urls2.isEmpty()) {
                return@withContext null
            }
            
            // 並列でダウンロード競争
            val result1Deferred = async { downloadRace(urls1.shuffled()) }
            val result2Deferred = async { downloadRace(urls2.shuffled()) }
            
            val (bitmap1, _) = result1Deferred.await()
            val (bitmap2, _) = result2Deferred.await()
            
            if (bitmap1 == null || bitmap2 == null) {
                return@withContext null
            }
            
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 同じ検索クエリから2枚の異なる画像を取得して合成（超高速版）
     */
    suspend fun createSameImage(query: String): Bitmap? = withContext(Dispatchers.IO) {
        // 現在の問題用のURL追跡をクリア
        currentQuestionUrls.clear()
        
        try {
            // より多くのURLを取得
            val urls = searchImages(query, maxResults = 40)
            
            // 使用済みURLを除外
            val unusedUrls = urls.filter { it !in usedUrls && it !in currentQuestionUrls }
            if (unusedUrls.size < 4) {
                return@withContext null
            }
            
            val shuffled = unusedUrls.shuffled()
            
            // 2セットを明確に分離（重複防止）
            val halfSize = shuffled.size / 2
            val firstSet = shuffled.take(halfSize)
            val secondSet = shuffled.drop(halfSize)
            
            if (firstSet.size < 2 || secondSet.size < 2) {
                return@withContext null
            }
            
            // 最初の画像を取得
            val (bitmap1, url1) = downloadRace(firstSet.take(5), markAsUsed = true)
            
            if (bitmap1 == null || url1 == null) {
                return@withContext null
            }
            
            // 2番目の画像を取得（別のセットから、url1を除外）
            val secondSetFiltered = secondSet.filter { it != url1 }
            val (bitmap2, url2) = downloadRace(secondSetFiltered.take(5), markAsUsed = true)
            
            // 同じ画像だった場合は失敗
            if (bitmap2 == null || url2 == null || url1 == url2) {
                return@withContext null
            }
            
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 2枚の画像を横に並べて合成
     */
    private fun combineImages(img1: Bitmap, img2: Bitmap): Bitmap {
        val ratio1 = TARGET_HEIGHT.toFloat() / img1.height
        val ratio2 = TARGET_HEIGHT.toFloat() / img2.height
        
        val newWidth1 = (img1.width * ratio1).toInt().coerceAtMost(MAX_WIDTH)
        val newWidth2 = (img2.width * ratio2).toInt().coerceAtMost(MAX_WIDTH)
        
        val scaled1 = Bitmap.createScaledBitmap(img1, newWidth1, TARGET_HEIGHT, true)
        val scaled2 = Bitmap.createScaledBitmap(img2, newWidth2, TARGET_HEIGHT, true)
        
        val gap = 16
        val combinedWidth = scaled1.width + gap + scaled2.width
        
        val combined = Bitmap.createBitmap(combinedWidth, TARGET_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(combined)
        
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(scaled1, 0f, 0f, null)
        canvas.drawBitmap(scaled2, (scaled1.width + gap).toFloat(), 0f, null)
        
        // スケーリングで新しいBitmapが作成された場合のみrecycle
        if (scaled1 !== img1) scaled1.recycle()
        if (scaled2 !== img2) scaled2.recycle()
        
        return combined
    }

    private fun isImageUrl(url: String): Boolean {
        val lower = url.lowercase()
        // 一般的な画像拡張子を含むかチェック（クエリパラメータ対応）
        return lower.contains(".jpg") || 
               lower.contains(".jpeg") || 
               lower.contains(".png") || 
               lower.contains(".webp") ||
               lower.contains(".gif") ||
               lower.contains(".bmp") ||
               lower.contains(".tiff") ||
               lower.contains("image") ||
               lower.contains("photo")
    }

    fun clearCache() {
        urlCache.clear()
        usedUrls.clear()
        currentQuestionUrls.clear()
        imageCache.values.forEach { 
            if (!it.isRecycled) it.recycle() 
        }
        imageCache.clear()
        // OkHttpの接続プールをクリア
        httpClient.connectionPool.evictAll()
    }
    
    fun clearUsedUrls() {
        usedUrls.clear()
        currentQuestionUrls.clear()
    }
}
