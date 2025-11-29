package com.example.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import kotlinx.coroutines.*
import org.jsoup.Jsoup
import java.net.HttpURLConnection
import java.net.URL

/**
 * 高速画像スクレイピングクラス
 * 並列ダウンロード、キャッシュ、タイムアウト最適化
 */
class ImageScraper {

    companion object {
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        private const val BING_URL = "https://www.bing.com/images/search"
        private const val CONNECT_TIMEOUT = 5000  // 5秒
        private const val READ_TIMEOUT = 5000     // 5秒
    }

    // URLキャッシュ（同じクエリは再検索しない）
    private val urlCache = mutableMapOf<String, List<String>>()

    /**
     * 検索クエリから画像URLリストを取得（キャッシュ付き）
     */
    suspend fun searchImages(query: String, maxResults: Int = 10): List<String> = withContext(Dispatchers.IO) {
        // キャッシュチェック
        urlCache[query]?.let { cached ->
            if (cached.size >= maxResults) return@withContext cached.take(maxResults)
        }

        val imageUrls = mutableListOf<String>()
        
        try {
            val searchUrl = "$BING_URL?q=${query.replace(" ", "+")}&form=HDRSC2&first=1"
            
            val doc = Jsoup.connect(searchUrl)
                .userAgent(USER_AGENT)
                .timeout(CONNECT_TIMEOUT)
                .get()
            
            // Bingの画像検索結果からURLを抽出
            val images = doc.select("a.iusc")
            
            for (element in images) {
                if (imageUrls.size >= maxResults * 2) break  // 余裕を持って取得
                
                try {
                    val dataM = element.attr("m")
                    if (dataM.isNotEmpty()) {
                        val murlMatch = Regex("\"murl\":\"([^\"]+)\"").find(dataM)
                        murlMatch?.groupValues?.get(1)?.let { url ->
                            if (url.startsWith("http") && isImageUrl(url)) {
                                imageUrls.add(url)
                            }
                        }
                    }
                } catch (e: Exception) {
                    continue
                }
            }
            
            // 代替方法
            if (imageUrls.isEmpty()) {
                val imgElements = doc.select("img.mimg")
                for (img in imgElements) {
                    if (imageUrls.size >= maxResults) break
                    val src = img.attr("src")
                    if (src.startsWith("http") && isImageUrl(src)) {
                        imageUrls.add(src)
                    }
                }
            }
            
            // キャッシュに保存
            if (imageUrls.isNotEmpty()) {
                urlCache[query] = imageUrls.toList()
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        imageUrls.take(maxResults)
    }

    /**
     * URLから画像をダウンロード（タイムアウト最適化）
     */
    suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
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
            
            connection.inputStream.use { input ->
                // サイズを小さくしてメモリ節約
                val options = BitmapFactory.Options().apply {
                    inSampleSize = 2  // 1/2サイズで読み込み
                }
                BitmapFactory.decodeStream(input, null, options)
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 複数URLから最初に成功した画像を取得（並列処理）
     */
    suspend fun downloadFirstAvailable(urls: List<String>): Bitmap? = withContext(Dispatchers.IO) {
        if (urls.isEmpty()) return@withContext null
        
        // 最大3つを並列でダウンロード試行
        val jobs = urls.take(3).map { url ->
            async {
                downloadImage(url)
            }
        }
        
        // 最初に成功したものを返す
        for (job in jobs) {
            val result = job.await()
            if (result != null) {
                // 他のジョブをキャンセル
                jobs.forEach { it.cancel() }
                return@withContext result
            }
        }
        null
    }

    /**
     * 2つの検索クエリから画像を取得して横並びに合成（高速版）
     */
    suspend fun createComparisonImage(query1: String, query2: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            // 並列で検索
            val urls1Deferred = async { searchImages(query1, 5) }
            val urls2Deferred = async { searchImages(query2, 5) }
            
            val urls1 = urls1Deferred.await()
            val urls2 = urls2Deferred.await()
            
            if (urls1.isEmpty() || urls2.isEmpty()) {
                return@withContext null
            }
            
            // 並列でダウンロード
            val bitmap1Deferred = async { downloadFirstAvailable(urls1.shuffled()) }
            val bitmap2Deferred = async { downloadFirstAvailable(urls2.shuffled()) }
            
            val bitmap1 = bitmap1Deferred.await()
            val bitmap2 = bitmap2Deferred.await()
            
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
     * 同じ検索クエリから2枚の画像を取得して合成（高速版）
     */
    suspend fun createSameImage(query: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val urls = searchImages(query, 10)
            
            if (urls.size < 2) {
                return@withContext null
            }
            
            val shuffled = urls.shuffled()
            
            // 並列でダウンロード
            val bitmap1Deferred = async { downloadFirstAvailable(listOf(shuffled[0], shuffled.getOrNull(2) ?: shuffled[0])) }
            val bitmap2Deferred = async { downloadFirstAvailable(listOf(shuffled[1], shuffled.getOrNull(3) ?: shuffled[1])) }
            
            val bitmap1 = bitmap1Deferred.await()
            val bitmap2 = bitmap2Deferred.await()
            
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
     * 2枚の画像を横に並べて合成
     */
    private fun combineImages(img1: Bitmap, img2: Bitmap): Bitmap {
        val targetHeight = 300  // 小さめにして高速化
        
        val ratio1 = targetHeight.toFloat() / img1.height
        val ratio2 = targetHeight.toFloat() / img2.height
        
        val newWidth1 = (img1.width * ratio1).toInt().coerceAtMost(400)
        val newWidth2 = (img2.width * ratio2).toInt().coerceAtMost(400)
        
        val scaled1 = Bitmap.createScaledBitmap(img1, newWidth1, targetHeight, false)
        val scaled2 = Bitmap.createScaledBitmap(img2, newWidth2, targetHeight, false)
        
        val gap = 16
        val combinedWidth = scaled1.width + gap + scaled2.width
        
        val combined = Bitmap.createBitmap(combinedWidth, targetHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(combined)
        
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(scaled1, 0f, 0f, null)
        canvas.drawBitmap(scaled2, (scaled1.width + gap).toFloat(), 0f, null)
        
        // 元画像をリサイクル
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
    }
}
