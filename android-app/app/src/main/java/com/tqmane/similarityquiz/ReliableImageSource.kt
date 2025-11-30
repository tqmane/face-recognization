package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * 信頼性の高い画像ソースを使用した画像取得クラス
 * 
 * 使用API（優先順）:
 * - iNaturalist: 野生動物（研究グレードの写真）
 * - GBIF: 生物多様性データ（自然史博物館等の写真）
 * - The Dog API: 犬種
 * - The Cat API: 猫種
 * - Unsplash: 高品質写真（車、風景等）
 * - Wikimedia Commons: その他（ロゴ等）
 */
class ReliableImageSource {

    companion object {
        private const val USER_AGENT = "SimilarityQuiz/1.0 (Educational Research App - Japanese High School)"
        
        // 画像サイズ設定
        private const val TARGET_HEIGHT = 450
        private const val MAX_WIDTH = 550
        
        // API URLs
        private const val INATURALIST_API = "https://api.inaturalist.org/v1"
        private const val GBIF_API = "https://api.gbif.org/v1"
        private const val DOG_API = "https://api.thedogapi.com/v1"
        private const val CAT_API = "https://api.thecatapi.com/v1"
        private const val UNSPLASH_API = "https://api.unsplash.com"
        private const val WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"
        private const val FLICKR_API = "https://api.flickr.com/services/rest"
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    // キャッシュ
    private val urlCache = ConcurrentHashMap<String, MutableList<String>>()
    private val usedUrls = ConcurrentHashMap.newKeySet<String>()
    private val currentQuestionUrls = ConcurrentHashMap.newKeySet<String>()
    private val imageCache = ConcurrentHashMap<String, Bitmap>()

    // ジャンルごとの画像ソース設定
    data class ImageSourceConfig(
        val source: ImageSource,
        val searchTerm: String,
        val additionalParams: Map<String, String> = emptyMap()
    )

    enum class ImageSource {
        INATURALIST,    // 野生動物全般
        DOG_API,        // 犬種
        CAT_API,        // 猫種
        WIKIMEDIA,      // その他（ロゴ、車など）
        BING_FALLBACK   // フォールバック
    }

    // 動物ID → iNaturalist taxon_id マッピング
    private val iNaturalistTaxonIds = mapOf(
        // ネコ科大型（正しいtaxon_id: 2024年12月確認）
        "cheetah" to 41955,         // Acinonyx jubatus
        "leopard" to 41963,         // Panthera pardus
        "jaguar" to 41970,          // Panthera onca
        "lion" to 41964,            // Panthera leo
        "tiger" to 41967,           // Panthera tigris
        "cougar" to 42007,          // Puma concolor
        "snow_leopard" to 74831,    // Panthera uncia
        "clouded_leopard" to 41972, // Neofelis nebulosa
        
        // 野生イヌ科
        "wolf" to 43351,
        "fox" to 42069,
        "arctic_fox" to 42076,
        "coyote" to 42050,
        "dingo" to 559543,
        "jackal" to 42039,
        
        // アライグマ系
        "raccoon" to 41663,
        "tanuki" to 42068,
        "red_panda" to 41656,
        "coati" to 41673,
        
        // 鳥類
        "crow" to 8021,
        "raven" to 9083,
        "hawk" to 5067,
        "eagle" to 5305,
        "falcon" to 4647,
        "owl" to 19350,
        "barn_owl" to 3442,
        
        // 海洋動物
        "sea_lion" to 41633,
        "seal" to 41631,
        "walrus" to 41620,
        "dolphin" to 41479,
        "orca" to 41523,
        "beluga" to 41530,
        "manatee" to 41586,
        "dugong" to 41587,
        
        // 爬虫類
        "alligator" to 26163,
        "crocodile" to 26159,
        "caiman" to 26166,
        "gharial" to 26172,
        "iguana" to 36383,
        "monitor" to 79437,
        "komodo" to 79439,
        
        // クマ科
        "brown_bear" to 41638,
        "black_bear" to 41647,
        "polar_bear" to 41637,
        "panda" to 41650,
        "spectacled_bear" to 41649,
        "sun_bear" to 41648,
        
        // 霊長類
        "chimpanzee" to 417394,
        "bonobo" to 417402,
        "gorilla" to 43571,
        "orangutan" to 43576,
        "gibbon" to 43581,
        "macaque" to 43549,
        "baboon" to 43531,
        "mandrill" to 43536,
        
        // 昆虫
        "bee" to 47219,
        "wasp" to 52747,
        "hornet" to 322285,
        "butterfly" to 47224,
        "moth" to 47157,
        "beetle" to 47208,
        "stag_beetle" to 48112,
        "ladybug" to 52748,
        "firefly" to 47945
    )

    // GBIF species key マッピング（自然史博物館等の写真）
    private val gbifSpeciesKeys = mapOf(
        // ネコ科大型
        "cheetah" to 5219404,
        "leopard" to 5219436,
        "jaguar" to 5219426,
        "lion" to 5219411,
        "tiger" to 5219446,
        "cougar" to 2435099,
        "snow_leopard" to 5219440,
        
        // 野生イヌ科
        "wolf" to 5219173,
        "fox" to 5219243,
        "arctic_fox" to 5219233,
        "coyote" to 5219142,
        
        // アライグマ系
        "raccoon" to 5218786,
        "red_panda" to 5218800,
        
        // クマ科
        "brown_bear" to 2433433,
        "black_bear" to 2433398,
        "polar_bear" to 2433451,
        "panda" to 5218781,
        
        // 霊長類
        "chimpanzee" to 5219513,
        "gorilla" to 5219521,
        "orangutan" to 5219531
    )

    // Dog API breed_id マッピング
    private val dogBreedIds = mapOf(
        "shiba" to 136,
        "akita" to 5,
        "husky" to 141,
        "malamute" to 5,
        "samoyed" to 130,
        "golden_retriever" to 63,
        "labrador" to 82,
        "german_shepherd" to 60,
        "border_collie" to 37,
        "australian_shepherd" to 13,
        "corgi" to 180,
        "pomeranian" to 109,
        "chow_chow" to 48
    )

    // Cat API breed_id マッピング
    private val catBreedIds = mapOf(
        "persian_cat" to "pers",
        "british_shorthair" to "bsho",
        "scottish_fold" to "sfol",
        "maine_coon" to "mcoo",
        "ragdoll" to "ragd",
        "siamese" to "siam",
        "russian_blue" to "rblu"
    )

    /**
     * 指定されたアイテムIDから画像URLを取得
     */
    suspend fun getImageUrls(itemId: String, maxResults: Int = 20): List<String> = withContext(Dispatchers.IO) {
        val startTime = System.currentTimeMillis()
        
        // キャッシュチェック
        urlCache[itemId]?.let { cached ->
            val unused = cached.filter { it !in usedUrls && it !in currentQuestionUrls }
            if (unused.size >= maxResults) {
                android.util.Log.d("ReliableImageSource", "Cache hit for '$itemId': ${unused.size} URLs")
                return@withContext unused.take(maxResults)
            }
        }

        val urls = mutableListOf<String>()

        try {
            // 1. iNaturalistを試す（動物 - 研究グレード）
            iNaturalistTaxonIds[itemId]?.let { taxonId ->
                val inatUrls = fetchFromINaturalist(taxonId)
                urls.addAll(inatUrls)
                android.util.Log.d("ReliableImageSource", "iNaturalist returned ${inatUrls.size} URLs for $itemId")
            }

            // 2. GBIFを試す（生物多様性データ - 自然史博物館等）
            if (urls.size < maxResults) {
                gbifSpeciesKeys[itemId]?.let { speciesKey ->
                    val gbifUrls = fetchFromGBIF(speciesKey)
                    urls.addAll(gbifUrls)
                    android.util.Log.d("ReliableImageSource", "GBIF returned ${gbifUrls.size} URLs for $itemId")
                }
            }

            // 3. Dog APIを試す（犬種）
            if (urls.size < maxResults) {
                dogBreedIds[itemId]?.let { breedId ->
                    val dogUrls = fetchFromDogApi(breedId)
                    urls.addAll(dogUrls)
                    android.util.Log.d("ReliableImageSource", "Dog API returned ${dogUrls.size} URLs for $itemId")
                }
            }

            // 4. Cat APIを試す（猫種）
            if (urls.size < maxResults) {
                catBreedIds[itemId]?.let { breedId ->
                    val catUrls = fetchFromCatApi(breedId)
                    urls.addAll(catUrls)
                    android.util.Log.d("ReliableImageSource", "Cat API returned ${catUrls.size} URLs for $itemId")
                }
            }

            // 5. Unsplashを試す（車、風景等の高品質写真）
            if (urls.size < maxResults / 2) {
                val unsplashUrls = fetchFromUnsplash(itemId)
                urls.addAll(unsplashUrls)
                android.util.Log.d("ReliableImageSource", "Unsplash returned ${unsplashUrls.size} URLs for $itemId")
            }

            // 6. Wikimedia Commonsを試す（その他・フォールバック）
            if (urls.size < maxResults / 2) {
                val wikiUrls = fetchFromWikimedia(itemId)
                urls.addAll(wikiUrls)
                android.util.Log.d("ReliableImageSource", "Wikimedia returned ${wikiUrls.size} URLs for $itemId")
            }

        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Error fetching URLs for $itemId: ${e.message}")
        }

        // キャッシュに保存
        if (urls.isNotEmpty()) {
            val existing = urlCache.getOrPut(itemId) { mutableListOf() }
            synchronized(existing) {
                urls.forEach { url -> if (url !in existing) existing.add(url) }
            }
        }

        val elapsed = System.currentTimeMillis() - startTime
        android.util.Log.d("ReliableImageSource", "getImageUrls for '$itemId' took ${elapsed}ms, found ${urls.size} URLs")

        urls.filter { it !in usedUrls && it !in currentQuestionUrls }.take(maxResults)
    }

    /**
     * iNaturalist APIから画像を取得
     */
    private suspend fun fetchFromINaturalist(taxonId: Int): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        try {
            val url = "$INATURALIST_API/observations?taxon_id=$taxonId&photos=true&quality_grade=research&per_page=30&order=desc&order_by=votes"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", USER_AGENT)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val json = JSONObject(response.body?.string() ?: "")
                    val results = json.optJSONArray("results") ?: JSONArray()
                    
                    for (i in 0 until results.length()) {
                        val observation = results.getJSONObject(i)
                        val photos = observation.optJSONArray("photos") ?: continue
                        
                        for (j in 0 until photos.length()) {
                            val photo = photos.getJSONObject(j)
                            // medium サイズを使用（バランス良い）
                            val photoUrl = photo.optString("url", "")
                                .replace("square", "medium")
                            if (photoUrl.isNotEmpty() && isValidImageUrl(photoUrl)) {
                                urls.add(photoUrl)
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "iNaturalist error: ${e.message}")
        }
        urls
    }

    /**
     * GBIF APIから画像を取得（自然史博物館等の写真）
     */
    private suspend fun fetchFromGBIF(speciesKey: Int): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        try {
            val url = "$GBIF_API/occurrence/search?speciesKey=$speciesKey&mediaType=StillImage&limit=30"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", USER_AGENT)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val json = JSONObject(response.body?.string() ?: "")
                    val results = json.optJSONArray("results") ?: JSONArray()
                    
                    for (i in 0 until results.length()) {
                        val occurrence = results.getJSONObject(i)
                        val media = occurrence.optJSONArray("media") ?: continue
                        
                        for (j in 0 until media.length()) {
                            val mediaItem = media.getJSONObject(j)
                            val identifier = mediaItem.optString("identifier", "")
                            if (identifier.isNotEmpty() && isValidImageUrl(identifier)) {
                                urls.add(identifier)
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "GBIF error: ${e.message}")
        }
        urls
    }

    /**
     * Unsplash Source APIから画像を取得（APIキー不要）
     */
    private suspend fun fetchFromUnsplash(itemId: String): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        val searchTerm = getUnsplashSearchTerm(itemId) ?: return@withContext urls
        
        try {
            // Unsplash Source API（APIキー不要、直接画像URL）
            // 複数のサイズバリエーションを生成
            for (i in 1..10) {
                val url = "https://source.unsplash.com/800x600/?$searchTerm&sig=$i"
                urls.add(url)
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Unsplash error: ${e.message}")
        }
        urls
    }

    private fun getUnsplashSearchTerm(itemId: String): String? {
        return when (itemId) {
            // 車
            "gt86", "brz" -> "sports,car,toyota"
            "miata" -> "mazda,miata,roadster"
            "s2000" -> "honda,s2000,car"
            "rx7" -> "mazda,rx7,sports,car"
            "supra" -> "toyota,supra,car"
            "nsx" -> "honda,nsx,supercar"
            "gtr" -> "nissan,gtr,sports,car"
            "370z" -> "nissan,370z,car"
            "mustang" -> "ford,mustang,car"
            "camaro" -> "chevrolet,camaro,car"
            "challenger" -> "dodge,challenger,car"
            else -> null
        }
    }

    /**
     * The Dog APIから画像を取得
     */
    private suspend fun fetchFromDogApi(breedId: Int): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        try {
            val url = "$DOG_API/images/search?breed_ids=$breedId&limit=20"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", USER_AGENT)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val results = JSONArray(response.body?.string() ?: "[]")
                    
                    for (i in 0 until results.length()) {
                        val item = results.getJSONObject(i)
                        val photoUrl = item.optString("url", "")
                        if (photoUrl.isNotEmpty() && isValidImageUrl(photoUrl)) {
                            urls.add(photoUrl)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Dog API error: ${e.message}")
        }
        urls
    }

    /**
     * The Cat APIから画像を取得
     */
    private suspend fun fetchFromCatApi(breedId: String): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        try {
            val url = "$CAT_API/images/search?breed_ids=$breedId&limit=20"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", USER_AGENT)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val results = JSONArray(response.body?.string() ?: "[]")
                    
                    for (i in 0 until results.length()) {
                        val item = results.getJSONObject(i)
                        val photoUrl = item.optString("url", "")
                        if (photoUrl.isNotEmpty() && isValidImageUrl(photoUrl)) {
                            urls.add(photoUrl)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Cat API error: ${e.message}")
        }
        urls
    }

    /**
     * Wikimedia Commonsから画像を取得
     */
    private suspend fun fetchFromWikimedia(itemId: String): List<String> = withContext(Dispatchers.IO) {
        val urls = mutableListOf<String>()
        
        // itemIdから検索ワードを生成
        val searchTerm = getWikimediaSearchTerm(itemId)
        
        try {
            val url = "$WIKIMEDIA_API?action=query&generator=search&gsrsearch=$searchTerm&gsrlimit=20&prop=imageinfo&iiprop=url&iiurlwidth=800&format=json"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", USER_AGENT)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val json = JSONObject(response.body?.string() ?: "{}")
                    val query = json.optJSONObject("query") ?: return@withContext urls
                    val pages = query.optJSONObject("pages") ?: return@withContext urls
                    
                    for (key in pages.keys()) {
                        val page = pages.getJSONObject(key)
                        val imageinfo = page.optJSONArray("imageinfo") ?: continue
                        
                        for (i in 0 until imageinfo.length()) {
                            val info = imageinfo.getJSONObject(i)
                            val photoUrl = info.optString("thumburl", info.optString("url", ""))
                            if (photoUrl.isNotEmpty() && isValidImageUrl(photoUrl)) {
                                urls.add(photoUrl)
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Wikimedia error: ${e.message}")
        }
        urls
    }

    private fun getWikimediaSearchTerm(itemId: String): String {
        return when (itemId) {
            // 車
            "gt86" -> "Toyota 86 car"
            "brz" -> "Subaru BRZ"
            "miata" -> "Mazda MX-5"
            "s2000" -> "Honda S2000"
            "rx7" -> "Mazda RX-7"
            "supra" -> "Toyota Supra"
            "nsx" -> "Honda NSX"
            "gtr" -> "Nissan GT-R"
            "370z" -> "Nissan 370Z"
            "mustang" -> "Ford Mustang"
            "camaro" -> "Chevrolet Camaro"
            "challenger" -> "Dodge Challenger"
            // ロゴ
            "pepsi" -> "Pepsi logo"
            "korean_air" -> "Korean Air logo"
            "carrefour" -> "Carrefour logo"
            "chanel" -> "Chanel logo"
            "gucci" -> "Gucci logo"
            "starbucks" -> "Starbucks logo"
            "costa" -> "Costa Coffee logo"
            "beats" -> "Beats logo"
            "monster" -> "Monster Energy logo"
            // 人物
            else -> itemId.replace("_", " ")
        }
    }

    /**
     * 画像URLが有効かチェック
     */
    private fun isValidImageUrl(url: String): Boolean {
        val lower = url.lowercase()
        return (lower.contains(".jpg") || lower.contains(".jpeg") || 
                lower.contains(".png") || lower.contains(".webp")) &&
               !lower.contains("placeholder") &&
               !lower.contains("default")
    }

    /**
     * URLから画像をダウンロード（メモリ効率改善版）
     */
    suspend fun downloadImage(imageUrl: String): Bitmap? = withContext(Dispatchers.IO) {
        if (imageUrl in usedUrls) return@withContext null
        
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
                
                // 画像サイズを取得して適切なサンプルサイズを計算
                val boundsOptions = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, boundsOptions)
                
                // 目標サイズ（設定から取得、デフォルト800px）
                val targetSize = AppSettings.getInstance().targetImageSize
                val sampleSize = calculateInSampleSize(boundsOptions, targetSize, targetSize)
                
                val options = BitmapFactory.Options().apply {
                    inPreferredConfig = Bitmap.Config.RGB_565  // メモリ半減
                    inSampleSize = sampleSize  // ダウンサンプリング
                }
                
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                
                // キャッシュサイズを制限（設定から取得）
                val maxCacheSize = AppSettings.getInstance().cacheSize
                if (bitmap != null && imageCache.size < maxCacheSize) {
                    imageCache[imageUrl] = bitmap
                }
                bitmap
            }
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "Download error: ${e.message}")
            null
        } catch (e: OutOfMemoryError) {
            android.util.Log.e("ReliableImageSource", "OutOfMemory during download: ${e.message}")
            // キャッシュをクリアしてメモリを解放
            clearCache()
            System.gc()
            null
        }
    }
    
    /**
     * 適切なサンプルサイズを計算
     */
    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val (height, width) = options.outHeight to options.outWidth
        var inSampleSize = 1
        
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            
            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    /**
     * 並列ダウンロード競争
     */
    suspend fun downloadRace(urls: List<String>, markAsUsed: Boolean = true): Pair<Bitmap?, String?> = withContext(Dispatchers.IO) {
        val raceStartTime = System.currentTimeMillis()
        if (urls.isEmpty()) return@withContext Pair(null, null)
        
        val availableUrls = urls.filter { it !in usedUrls && it !in currentQuestionUrls }
        if (availableUrls.isEmpty()) {
            android.util.Log.w("ReliableImageSource", "No available URLs for download race")
            return@withContext Pair(null, null)
        }
        
        val result = CompletableDeferred<Pair<Bitmap?, String?>>()
        val jobs = mutableListOf<Job>()
        
        // 並列ダウンロード数を設定から取得
        val parallelDownloads = AppSettings.getInstance().parallelDownloads
        availableUrls.take(parallelDownloads).forEach { url ->
            val job = launch {
                val bitmap = downloadImage(url)
                if (bitmap != null && result.isActive) {
                    if (result.complete(Pair(bitmap, url))) {
                        if (markAsUsed) usedUrls.add(url)
                        currentQuestionUrls.add(url)
                    }
                }
            }
            jobs.add(job)
        }
        
        // タイムアウトを設定から取得
        val timeout = AppSettings.getInstance().downloadTimeout * 1000L
        val winner = withTimeoutOrNull(timeout) { result.await() }
        jobs.forEach { it.cancel() }
        
        val raceTime = System.currentTimeMillis() - raceStartTime
        if (winner == null) {
            android.util.Log.w("ReliableImageSource", "Download race timed out after ${raceTime}ms")
        } else {
            android.util.Log.d("ReliableImageSource", "Download race won in ${raceTime}ms")
        }
        
        winner ?: Pair(null, null)
    }

    /**
     * 2つのアイテムから比較画像を作成
     */
    suspend fun createComparisonImage(itemId1: String, itemId2: String): Bitmap? = withContext(Dispatchers.IO) {
        currentQuestionUrls.clear()
        
        try {
            val urls1Deferred = async { getImageUrls(itemId1) }
            val urls2Deferred = async { getImageUrls(itemId2) }
            
            val urls1 = urls1Deferred.await()
            val urls2 = urls2Deferred.await()
            
            if (urls1.isEmpty() || urls2.isEmpty()) {
                android.util.Log.w("ReliableImageSource", "No URLs found: $itemId1=${urls1.size}, $itemId2=${urls2.size}")
                return@withContext null
            }
            
            val result1Deferred = async { downloadRace(urls1.shuffled()) }
            val result2Deferred = async { downloadRace(urls2.shuffled()) }
            
            val (bitmap1, _) = result1Deferred.await()
            val (bitmap2, _) = result2Deferred.await()
            
            if (bitmap1 == null || bitmap2 == null) {
                android.util.Log.w("ReliableImageSource", "Download failed: bitmap1=${bitmap1 != null}, bitmap2=${bitmap2 != null}")
                return@withContext null
            }
            
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "createComparisonImage error: ${e.message}")
            null
        }
    }

    /**
     * 同じアイテムから2枚の異なる画像を作成
     */
    suspend fun createSameImage(itemId: String): Bitmap? = withContext(Dispatchers.IO) {
        currentQuestionUrls.clear()
        
        try {
            val urls = getImageUrls(itemId, maxResults = 40)
            
            val unusedUrls = urls.filter { it !in usedUrls && it !in currentQuestionUrls }
            if (unusedUrls.size < 4) {
                android.util.Log.w("ReliableImageSource", "Not enough URLs for $itemId: ${unusedUrls.size}")
                return@withContext null
            }
            
            val shuffled = unusedUrls.shuffled()
            val halfSize = shuffled.size / 2
            val firstSet = shuffled.take(halfSize)
            val secondSet = shuffled.drop(halfSize)
            
            val (bitmap1, url1) = downloadRace(firstSet.take(5), markAsUsed = true)
            if (bitmap1 == null || url1 == null) return@withContext null
            
            val secondSetFiltered = secondSet.filter { it != url1 }
            val (bitmap2, url2) = downloadRace(secondSetFiltered.take(5), markAsUsed = true)
            
            if (bitmap2 == null || url2 == null || url1 == url2) return@withContext null
            
            combineImages(bitmap1, bitmap2)
        } catch (e: Exception) {
            android.util.Log.e("ReliableImageSource", "createSameImage error: ${e.message}")
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
        
        if (scaled1 !== img1) scaled1.recycle()
        if (scaled2 !== img2) scaled2.recycle()
        
        return combined
    }

    fun clearCache() {
        urlCache.clear()
        usedUrls.clear()
        currentQuestionUrls.clear()
        imageCache.values.forEach { if (!it.isRecycled) it.recycle() }
        imageCache.clear()
    }
    
    fun clearUsedUrls() {
        usedUrls.clear()
        currentQuestionUrls.clear()
    }
}
