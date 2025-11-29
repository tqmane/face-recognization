package com.example.similarityquiz

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
    }

    // スレッドセーフなキャッシュ
    private val urlCache = ConcurrentHashMap<String, MutableList<String>>()
    private val usedUrls = ConcurrentHashMap.newKeySet<String>()
    
    // プリフェッチ済み画像キャッシュ
    private val imageCache = ConcurrentHashMap<String, Bitmap>()

    /**
     * 検索クエリから画像URLリストを取得
     */
    suspend fun searchImages(query: String, maxResults: Int = 30): List<String> = withContext(Dispatchers.IO) {
        // キャッシュから未使用のURLを取得
        urlCache[query]?.let { cached ->
            val unused = cached.filter { it !in usedUrls }
            if (unused.size >= maxResults) {
                return@withContext unused.take(maxResults)
            }
        }

        val imageUrls = mutableListOf<String>()
        
        try {
            val searchUrl = "$BING_URL?q=${query.replace(" ", "+")}&form=HDRSC2&first=1&count=100"
            
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
                            if (url.startsWith("http") && isImageUrl(url) && url !in usedUrls) {
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
        
        imageUrls.filter { it !in usedUrls }.take(maxResults)
    }

    /**
     * URLから画像をダウンロード（高速版）
     */
    private suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
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
     * 複数URLから並列で最速ダウンロード
     */
    private suspend fun downloadRace(urls: List<String>): Pair<Bitmap?, String?> = withContext(Dispatchers.IO) {
        if (urls.isEmpty()) return@withContext Pair(null, null)
        
        val unusedUrls = urls.filter { it !in usedUrls }
        if (unusedUrls.isEmpty()) return@withContext Pair(null, null)
        
        // 最大5つを並列ダウンロード（競争）
        val result = CompletableDeferred<Pair<Bitmap?, String?>>()
        val jobs = mutableListOf<Job>()
        
        unusedUrls.take(5).forEach { url ->
            val job = launch {
                val bitmap = downloadImage(url)
                if (bitmap != null && result.isActive) {
                    if (result.complete(Pair(bitmap, url))) {
                        usedUrls.add(url)
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
        try {
            val urls = searchImages(query)
            
            val unusedUrls = urls.filter { it !in usedUrls }
            if (unusedUrls.size < 4) {
                return@withContext null
            }
            
            val shuffled = unusedUrls.shuffled()
            
            // 2セットを並列でダウンロード
            val result1Deferred = async { downloadRace(shuffled.take(5)) }
            val result2Deferred = async { downloadRace(shuffled.drop(5).take(5)) }
            
            val (bitmap1, url1) = result1Deferred.await()
            val (bitmap2, url2) = result2Deferred.await()
            
            // 同じ画像だった場合は失敗
            if (bitmap1 == null || bitmap2 == null || url1 == url2) {
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
        
        if (scaled1 != img1) img1.recycle()
        if (scaled2 != img2) img2.recycle()
        
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
        imageCache.values.forEach { it.recycle() }
        imageCache.clear()
    }
    
    fun clearUsedUrls() {
        usedUrls.clear()
    }
}
