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
 * 重複防止、高解像度対応
 */
class ImageScraper {

    companion object {
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        private const val BING_URL = "https://www.bing.com/images/search"
        private const val CONNECT_TIMEOUT = 5000
        private const val READ_TIMEOUT = 5000
        
        // 解像度設定（高解像度化）
        private const val TARGET_HEIGHT = 500  // 300 → 500
        private const val MAX_WIDTH = 600      // 400 → 600
    }

    // URLキャッシュ（同じクエリは再検索しない）
    private val urlCache = mutableMapOf<String, MutableList<String>>()
    
    // 使用済みURL（重複防止）
    private val usedUrls = mutableSetOf<String>()

    /**
     * 検索クエリから画像URLリストを取得（キャッシュ付き）
     */
    suspend fun searchImages(query: String, maxResults: Int = 20): List<String> = withContext(Dispatchers.IO) {
        // キャッシュから未使用のURLを取得
        urlCache[query]?.let { cached ->
            val unused = cached.filter { it !in usedUrls }
            if (unused.size >= maxResults) {
                return@withContext unused.take(maxResults)
            }
        }

        val imageUrls = mutableListOf<String>()
        
        try {
            // より多くの結果を取得するためにパラメータを追加
            val searchUrl = "$BING_URL?q=${query.replace(" ", "+")}&form=HDRSC2&first=1&count=50"
            
            val doc = Jsoup.connect(searchUrl)
                .userAgent(USER_AGENT)
                .timeout(CONNECT_TIMEOUT)
                .get()
            
            val images = doc.select("a.iusc")
            
            for (element in images) {
                if (imageUrls.size >= maxResults * 3) break
                
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
            
            // 代替方法
            if (imageUrls.isEmpty()) {
                val imgElements = doc.select("img.mimg")
                for (img in imgElements) {
                    if (imageUrls.size >= maxResults) break
                    val src = img.attr("src")
                    if (src.startsWith("http") && isImageUrl(src) && src !in usedUrls) {
                        imageUrls.add(src)
                    }
                }
            }
            
            // キャッシュに追加（既存のものとマージ）
            if (imageUrls.isNotEmpty()) {
                val existing = urlCache.getOrPut(query) { mutableListOf() }
                imageUrls.forEach { url ->
                    if (url !in existing) existing.add(url)
                }
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        imageUrls.filter { it !in usedUrls }.take(maxResults)
    }

    /**
     * URLから画像をダウンロード（高解像度）
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
                // 高解像度で読み込み（inSampleSize を削除）
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 複数URLから最初に成功した画像を取得、使用済みとしてマーク
     */
    suspend fun downloadFirstAvailable(urls: List<String>): Pair<Bitmap?, String?> = withContext(Dispatchers.IO) {
        if (urls.isEmpty()) return@withContext Pair(null, null)
        
        // 未使用URLのみをフィルタ
        val unusedUrls = urls.filter { it !in usedUrls }
        if (unusedUrls.isEmpty()) return@withContext Pair(null, null)
        
        val jobs = unusedUrls.take(3).map { url ->
            async {
                Pair(downloadImage(url), url)
            }
        }
        
        for (job in jobs) {
            val (bitmap, url) = job.await()
            if (bitmap != null && url != null) {
                // 使用済みとしてマーク
                usedUrls.add(url)
                jobs.forEach { it.cancel() }
                return@withContext Pair(bitmap, url)
            }
        }
        Pair(null, null)
    }

    /**
     * 2つの検索クエリから画像を取得して横並びに合成
     */
    suspend fun createComparisonImage(query1: String, query2: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            // 並列で検索（より多く取得）
            val urls1Deferred = async { searchImages(query1, 15) }
            val urls2Deferred = async { searchImages(query2, 15) }
            
            val urls1 = urls1Deferred.await()
            val urls2 = urls2Deferred.await()
            
            if (urls1.isEmpty() || urls2.isEmpty()) {
                return@withContext null
            }
            
            // 並列でダウンロード
            val result1Deferred = async { downloadFirstAvailable(urls1.shuffled()) }
            val result2Deferred = async { downloadFirstAvailable(urls2.shuffled()) }
            
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
     * 同じ検索クエリから2枚の異なる画像を取得して合成
     */
    suspend fun createSameImage(query: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val urls = searchImages(query, 20)
            
            // 未使用URLをフィルタ
            val unusedUrls = urls.filter { it !in usedUrls }
            if (unusedUrls.size < 2) {
                return@withContext null
            }
            
            val shuffled = unusedUrls.shuffled()
            
            // 異なるURLから2枚ダウンロード
            val (bitmap1, url1) = downloadFirstAvailable(listOf(shuffled[0]))
            if (bitmap1 == null) return@withContext null
            
            // 最初の画像のURLを除外して2枚目を取得
            val remainingUrls = shuffled.drop(1).filter { it != url1 }
            val (bitmap2, _) = downloadFirstAvailable(remainingUrls)
            if (bitmap2 == null) {
                bitmap1.recycle()
                return@withContext null
            }
            
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 2枚の画像を横に並べて合成（高解像度）
     */
    private fun combineImages(img1: Bitmap, img2: Bitmap): Bitmap {
        val ratio1 = TARGET_HEIGHT.toFloat() / img1.height
        val ratio2 = TARGET_HEIGHT.toFloat() / img2.height
        
        val newWidth1 = (img1.width * ratio1).toInt().coerceAtMost(MAX_WIDTH)
        val newWidth2 = (img2.width * ratio2).toInt().coerceAtMost(MAX_WIDTH)
        
        // 高品質スケーリング
        val scaled1 = Bitmap.createScaledBitmap(img1, newWidth1, TARGET_HEIGHT, true)
        val scaled2 = Bitmap.createScaledBitmap(img2, newWidth2, TARGET_HEIGHT, true)
        
        val gap = 20
        val combinedWidth = scaled1.width + gap + scaled2.width
        
        // 高品質出力（RGB_565 → ARGB_8888）
        val combined = Bitmap.createBitmap(combinedWidth, TARGET_HEIGHT, Bitmap.Config.ARGB_8888)
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

    /**
     * キャッシュと使用済みURLをクリア
     */
    fun clearCache() {
        urlCache.clear()
        usedUrls.clear()
    }
    
    /**
     * 使用済みURLのみクリア（新しいテスト開始時）
     */
    fun clearUsedUrls() {
        usedUrls.clear()
    }
}
