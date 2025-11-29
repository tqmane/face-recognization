package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import kotlinx.coroutines.*
import org.jsoup.Jsoup
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

/**
 * 超高速画像スクレイピングクラス
 * 積極的プリフェッチ、並列ダウンロード最大化
 */
class ImageScraper {

    companion object {
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        private const val BING_URL = "https://www.bing.com/images/search"
        private const val CONNECT_TIMEOUT = 3000  // 3秒に短縮
        private const val READ_TIMEOUT = 3000     // 3秒に短縮
        
        private const val TARGET_HEIGHT = 450
        private const val MAX_WIDTH = 550
        
        // 除外キーワード（最小限に縮小）
        private val EXCLUDE_KEYWORDS = listOf(
            "AI generated", "イラスト", "illustration", "drawing",
            "anime", "アニメ", "manga", "漫画"
        )
        
        // 除外ドメイン（イラスト系のみ）
        private val EXCLUDE_DOMAINS = listOf(
            "deviantart.com", "pixiv.net", "artstation.com"
        )
        
        // ランダムオフセットの範囲（多様性向上）
        private val RANDOM_OFFSETS = listOf(1, 35, 70, 105, 140)
    }

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
        // キャッシュから未使用のURLを取得
        urlCache[query]?.let { cached ->
            val unused = cached.filter { it !in usedUrls && it !in currentQuestionUrls }
            if (unused.size >= maxResults) {
                return@withContext unused.take(maxResults)
            }
        }

        val imageUrls = mutableListOf<String>()
        
        try {
            // ランダムなオフセットで多様な結果を取得
            val randomOffset = RANDOM_OFFSETS.random()
            // 写真フィルタと除外キーワードを追加
            val excludeTerms = EXCLUDE_KEYWORDS.joinToString(" ") { "-$it" }
            val enhancedQuery = "$query $excludeTerms"
            // qft=+filterui:photo-photo で写真のみにフィルタ
            val searchUrl = "$BING_URL?q=${enhancedQuery.replace(" ", "+")}&form=HDRSC2&first=$randomOffset&count=100&qft=+filterui:photo-photo"
            
            val doc = Jsoup.connect(searchUrl)
                .userAgent(USER_AGENT)
                .timeout(CONNECT_TIMEOUT)
                .get()
            
            val images = doc.select("a.iusc")
            
            for (element in images) {
                if (imageUrls.size >= 50) break
                
                try {
                    val dataM = element.attr("m")
                    if (dataM.isNotEmpty()) {
                        val murlMatch = Regex("\"murl\":\"([^\"]+)\"").find(dataM)
                        murlMatch?.groupValues?.get(1)?.let { url ->
                            // 使用済みURLと現在選択中のURLを除外
                            // 除外ドメインをチェック
                            val isExcludedDomain = EXCLUDE_DOMAINS.any { domain -> 
                                url.lowercase().contains(domain) 
                            }
                            if (url.startsWith("http") && isImageUrl(url) && 
                                url !in usedUrls && url !in currentQuestionUrls &&
                                !isExcludedDomain) {
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
     * URLから画像をダウンロード（高速版）
     */
    private suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
        // 既に使用済みならスキップ
        if (imageUrl in usedUrls) return@withContext null
        
        // キャッシュチェック
        imageCache[imageUrl]?.let { return@withContext it }
        
        try {
            val url = URL(imageUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.setRequestProperty("User-Agent", USER_AGENT)
            connection.connectTimeout = CONNECT_TIMEOUT
            connection.readTimeout = READ_TIMEOUT
            connection.instanceFollowRedirects = true
            
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext null
            }
            
            val bitmap = connection.inputStream.use { input ->
                BitmapFactory.decodeStream(input)
            }
            
            // キャッシュに保存
            bitmap?.let { imageCache[imageUrl] = it }
            bitmap
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 複数URLから並列で最速ダウンロード（指定されたURLのみを使用）
     */
    private suspend fun downloadRace(urls: List<String>, markAsUsed: Boolean = true): Pair<Bitmap?, String?> = withContext(Dispatchers.IO) {
        if (urls.isEmpty()) return@withContext Pair(null, null)
        
        // 使用済みURLを除外
        val availableUrls = urls.filter { it !in usedUrls && it !in currentQuestionUrls }
        if (availableUrls.isEmpty()) return@withContext Pair(null, null)
        
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
        return lower.contains(".jpg") || 
               lower.contains(".jpeg") || 
               lower.contains(".png") || 
               lower.contains(".webp")
    }

    fun clearCache() {
        urlCache.clear()
        usedUrls.clear()
        currentQuestionUrls.clear()
        imageCache.values.forEach { it.recycle() }
        imageCache.clear()
    }
    
    fun clearUsedUrls() {
        usedUrls.clear()
        currentQuestionUrls.clear()
    }
}
