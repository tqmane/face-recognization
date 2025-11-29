package com.example.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import java.net.URL

/**
 * 画像スクレイピングクラス
 * Bing画像検索から直接画像を取得（APIキー不要）
 */
class ImageScraper {

    companion object {
        private const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        private const val BING_URL = "https://www.bing.com/images/search"
    }

    /**
     * 検索クエリから画像URLリストを取得
     */
    suspend fun searchImages(query: String, maxResults: Int = 10): List<String> = withContext(Dispatchers.IO) {
        val imageUrls = mutableListOf<String>()
        
        try {
            val searchUrl = "$BING_URL?q=${query.replace(" ", "+")}&form=HDRSC2&first=1"
            
            val doc = Jsoup.connect(searchUrl)
                .userAgent(USER_AGENT)
                .timeout(10000)
                .get()
            
            // Bingの画像検索結果からサムネイルURLを抽出
            val images = doc.select("a.iusc")
            
            for (element in images) {
                if (imageUrls.size >= maxResults) break
                
                try {
                    // data-m属性からJSON風のデータを取得
                    val dataM = element.attr("m")
                    if (dataM.isNotEmpty()) {
                        // murl（元画像URL）を抽出
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
            
            // 代替方法: img タグから直接取得
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
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        imageUrls
    }

    /**
     * URLから画像をダウンロード
     */
    suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val connection = URL(imageUrl).openConnection()
            connection.setRequestProperty("User-Agent", USER_AGENT)
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            connection.getInputStream().use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 2つの検索クエリから画像を取得して横並びに合成
     */
    suspend fun createComparisonImage(query1: String, query2: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            // 両方の検索を実行
            val urls1 = searchImages(query1, 5)
            val urls2 = searchImages(query2, 5)
            
            if (urls1.isEmpty() || urls2.isEmpty()) {
                return@withContext null
            }
            
            // ランダムに1枚ずつ選択
            val url1 = urls1.random()
            val url2 = urls2.random()
            
            // 画像をダウンロード
            val bitmap1 = downloadImage(url1)
            val bitmap2 = downloadImage(url2)
            
            if (bitmap1 == null || bitmap2 == null) {
                return@withContext bitmap1 ?: bitmap2
            }
            
            // 横に並べて合成
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * 同じ検索クエリから2枚の画像を取得して合成（同じもの用）
     */
    suspend fun createSameImage(query: String): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val urls = searchImages(query, 10)
            
            if (urls.size < 2) {
                return@withContext null
            }
            
            // シャッフルして2枚選択
            val shuffled = urls.shuffled()
            val url1 = shuffled[0]
            val url2 = shuffled[1]
            
            val bitmap1 = downloadImage(url1)
            val bitmap2 = downloadImage(url2)
            
            if (bitmap1 == null || bitmap2 == null) {
                return@withContext bitmap1 ?: bitmap2
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
        val targetHeight = 400
        
        // リサイズ
        val ratio1 = targetHeight.toFloat() / img1.height
        val ratio2 = targetHeight.toFloat() / img2.height
        
        val newWidth1 = (img1.width * ratio1).toInt()
        val newWidth2 = (img2.width * ratio2).toInt()
        
        val scaled1 = Bitmap.createScaledBitmap(img1, newWidth1, targetHeight, true)
        val scaled2 = Bitmap.createScaledBitmap(img2, newWidth2, targetHeight, true)
        
        // 合成
        val gap = 20
        val combinedWidth = scaled1.width + gap + scaled2.width
        
        val combined = Bitmap.createBitmap(combinedWidth, targetHeight, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(combined)
        
        // 背景を白に
        canvas.drawColor(android.graphics.Color.WHITE)
        
        // 画像を配置
        canvas.drawBitmap(scaled1, 0f, 0f, null)
        canvas.drawBitmap(scaled2, (scaled1.width + gap).toFloat(), 0f, null)
        
        return combined
    }

    private fun isImageUrl(url: String): Boolean {
        val lower = url.lowercase()
        return lower.contains(".jpg") || 
               lower.contains(".jpeg") || 
               lower.contains(".png") || 
               lower.contains(".webp")
    }
}
