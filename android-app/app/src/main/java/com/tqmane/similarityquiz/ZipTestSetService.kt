package com.tqmane.similarityquiz

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * ZIPテストセット管理サービス
 * GitHubからZIPをダウンロードして展開・管理
 */
class ZipTestSetService(private val context: Context) {
    
    companion object {
        private const val BASE_URL = "https://raw.githubusercontent.com/tqmane/face-recognization/main/sets_pics"
        
        // 利用可能なテストセット
        val AVAILABLE_TEST_SETS = listOf(
            TestSetInfo("dogs", "犬種", "柴犬・秋田犬・ハスキーなど似ている犬種"),
            TestSetInfo("small_cats", "ネコ科", "ペルシャ・スコフォ・メインクーンなど"),
            TestSetInfo("wild_dogs", "犬と野生動物", "オオカミ・キツネ・コヨーテなど"),
            TestSetInfo("raccoons", "アライグマ系", "アライグマ・タヌキ・レッサーパンダなど"),
            TestSetInfo("birds", "鳥類", "カラス・ワタリガラス・鷹・鷲など"),
            TestSetInfo("marine", "海洋動物", "アシカ・アザラシ・イルカ・シャチなど"),
            TestSetInfo("reptiles", "爬虫類", "ワニ・クロコダイル・イグアナなど"),
            TestSetInfo("bears", "クマ科", "ヒグマ・ホッキョクグマ・パンダなど"),
            TestSetInfo("primates", "霊長類", "チンパンジー・ゴリラ・オランウータンなど"),
            TestSetInfo("insects", "昆虫", "蝶・蛾・蜂・アブなど")
        )
    }
    
    data class TestSetInfo(
        val id: String,
        val displayName: String,
        val description: String
    )
    
    data class DownloadedTestSet(
        val id: String,
        val displayName: String,
        val localPath: String,
        val imageCount: Int
    )
    
    data class TestSetManifest(
        val version: Int,
        val genre: String,
        val displayName: String,
        val types: Map<String, TypeInfo>,
        val similarPairs: List<SimilarPair>
    )
    
    data class TypeInfo(
        val displayName: String,
        val count: Int
    )
    
    data class SimilarPair(
        val id1: String,
        val id2: String
    )
    
    data class QuizQuestion(
        val image1Path: String,
        val image2Path: String,
        val type1: String,
        val type2: String,
        val type1DisplayName: String,
        val type2DisplayName: String,
        val isSame: Boolean
    ) {
        val description: String
            get() = if (isSame) "$type1DisplayName × $type1DisplayName" 
                    else "$type1DisplayName × $type2DisplayName"
    }
    
    private val testSetsDir: File
        get() = File(context.filesDir, "test_sets")

    data class DownloadResult(
        val success: Boolean,
        val errorMessage: String? = null
    )

    private fun normalizeZipEntryPath(entryName: String): String {
        val normalized = entryName.replace('\\', '/')
        if (normalized.startsWith("/") || normalized.startsWith("\\")) {
            throw IllegalArgumentException("Invalid zip entry path (absolute)")
        }
        if (normalized.contains(":")) {
            throw IllegalArgumentException("Invalid zip entry path (drive)")
        }

        val parts = normalized.split("/")
        val safeParts = mutableListOf<String>()
        for (part in parts) {
            if (part.isEmpty() || part == ".") continue
            if (part == "..") {
                if (safeParts.isEmpty()) {
                    throw IllegalArgumentException("Invalid zip entry path (traversal)")
                }
                safeParts.removeAt(safeParts.lastIndex)
                continue
            }
            safeParts.add(part)
        }
        if (safeParts.isEmpty()) {
            throw IllegalArgumentException("Invalid zip entry path (empty)")
        }
        return safeParts.joinToString("/")
    }

    private fun safeResolveZipEntry(extractDir: File, entryName: String): File {
        val safeRelative = normalizeZipEntryPath(entryName)
        val outFile = File(extractDir, safeRelative)
        val canonicalBase = extractDir.canonicalFile
        val canonicalOut = outFile.canonicalFile
        val basePath = canonicalBase.path.trimEnd(File.separatorChar) + File.separator
        if (!canonicalOut.path.startsWith(basePath)) {
            throw IllegalArgumentException("Invalid zip entry path (escape)")
        }
        return canonicalOut
    }
    
    /**
     * ダウンロード済みのテストセット一覧を取得
     */
    fun getDownloadedTestSets(): List<DownloadedTestSet> {
        val dir = testSetsDir
        if (!dir.exists()) return emptyList()
        
        return dir.listFiles()
            ?.filter { it.isDirectory }
            ?.mapNotNull { folder ->
                val info = AVAILABLE_TEST_SETS.find { it.id == folder.name }
                if (info != null) {
                    val imageCount = countImages(folder)
                    DownloadedTestSet(
                        id = info.id,
                        displayName = info.displayName,
                        localPath = folder.absolutePath,
                        imageCount = imageCount
                    )
                } else null
            } ?: emptyList()
    }
    
    private fun countImages(folder: File): Int {
        var count = 0
        folder.listFiles()?.forEach { subDir ->
            if (subDir.isDirectory) {
                count += subDir.listFiles()?.count { 
                    it.isFile && (it.extension == "jpg" || it.extension == "jpeg" || it.extension == "png")
                } ?: 0
            }
        }
        return count
    }
    
    /**
     * テストセットをダウンロード
     */
    suspend fun downloadTestSet(
        testSet: TestSetInfo,
        onProgress: (Float) -> Unit
    ): DownloadResult = withContext(Dispatchers.IO) {
        var tempFile: File? = null
        var extractDir: File? = null
        try {
            val url = URL("$BASE_URL/${testSet.id}.zip")
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 30000
            connection.readTimeout = 60000

            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext DownloadResult(
                    success = false,
                    errorMessage = "ダウンロードに失敗しました（$responseCode）"
                )
            }
            
            val totalSize = connection.contentLength
            var downloadedSize = 0
            
            withContext(Dispatchers.Main) {
                onProgress(0f)
            }
            tempFile = File(context.cacheDir, "${testSet.id}.zip")
            
            connection.inputStream.use { input ->
                FileOutputStream(tempFile!!).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloadedSize += bytesRead
                        if (totalSize > 0) {
                            withContext(Dispatchers.Main) {
                                onProgress(downloadedSize.toFloat() / totalSize)
                            }
                        }
                    }
                }
            }
            
            // ZIPを展開
            extractDir = File(testSetsDir, testSet.id)
            if (extractDir!!.exists()) {
                extractDir!!.deleteRecursively()
            }
            extractDir!!.mkdirs()
            
            ZipInputStream(tempFile!!.inputStream()).use { zip ->
                var entry = zip.nextEntry
                while (entry != null) {
                    val file = safeResolveZipEntry(extractDir!!, entry.name)
                    if (entry.isDirectory) {
                        file.mkdirs()
                    } else {
                        file.parentFile?.mkdirs()
                        FileOutputStream(file).use { output ->
                            zip.copyTo(output)
                        }
                    }
                    zip.closeEntry()
                    entry = zip.nextEntry
                }
            }
            
            // manifest.json があるか確認
            val manifestFile = File(extractDir!!, "manifest.json")
            if (!manifestFile.exists()) {
                extractDir!!.deleteRecursively()
                return@withContext DownloadResult(
                    success = false,
                    errorMessage = "テストセットの形式が不正です（manifest.json がありません）"
                )
            }

            DownloadResult(success = true)
        } catch (e: Exception) {
            e.printStackTrace()
            extractDir?.deleteRecursively()
            DownloadResult(success = false, errorMessage = "ダウンロード処理に失敗しました")
        } finally {
            tempFile?.delete()
        }
    }
    
    /**
     * テストセットを削除
     */
    fun deleteTestSet(id: String): Boolean {
        val dir = File(testSetsDir, id)
        return if (dir.exists()) {
            dir.deleteRecursively()
        } else false
    }
    
    /**
     * マニフェストを読み込み
     */
    fun loadManifest(testSetId: String): TestSetManifest? {
        val manifestFile = File(testSetsDir, "$testSetId/manifest.json")
        if (!manifestFile.exists()) return null
        
        return try {
            val json = JSONObject(manifestFile.readText())
            val typesJson = json.optJSONObject("types") ?: JSONObject()
            val types = mutableMapOf<String, TypeInfo>()
            typesJson.keys().forEach { key ->
                val typeObj = typesJson.getJSONObject(key)
                types[key] = TypeInfo(
                    displayName = typeObj.optString("display_name", key),
                    count = typeObj.optInt("count", 0)
                )
            }
            
            val pairsJson = json.optJSONArray("similar_pairs") ?: org.json.JSONArray()
            val pairs = mutableListOf<SimilarPair>()
            for (i in 0 until pairsJson.length()) {
                val pairObj = pairsJson.getJSONObject(i)
                pairs.add(SimilarPair(
                    id1 = pairObj.getString("id1"),
                    id2 = pairObj.getString("id2")
                ))
            }
            
            TestSetManifest(
                version = json.optInt("version", 1),
                genre = json.optString("genre", ""),
                displayName = json.optString("display_name", ""),
                types = types,
                similarPairs = pairs
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    /**
     * クイズ問題を生成
     */
    fun generateQuestions(testSetId: String, count: Int): List<QuizQuestion> {
        val manifest = loadManifest(testSetId) ?: return emptyList()
        val testSetDir = File(testSetsDir, testSetId)
        
        // 各タイプの画像パスを収集
        val imagesByType = mutableMapOf<String, MutableList<String>>()
        manifest.types.keys.forEach { typeId ->
            val typeDir = File(testSetDir, typeId)
            if (typeDir.exists()) {
                val images = typeDir.listFiles()
                    ?.filter { it.extension in listOf("jpg", "jpeg", "png") }
                    ?.map { it.absolutePath }
                    ?.toMutableList() ?: mutableListOf()
                if (images.isNotEmpty()) {
                    imagesByType[typeId] = images
                }
            }
        }
        
        if (imagesByType.isEmpty()) return emptyList()
        
        val questions = mutableListOf<QuizQuestion>()
        val sameCount = count / 2
        
        // 同じ種類の問題を生成
        val typesWithMultipleImages = imagesByType.filter { it.value.size >= 2 }
        repeat(sameCount) {
            if (typesWithMultipleImages.isEmpty()) return@repeat
            val typeId = typesWithMultipleImages.keys.random()
            val images = typesWithMultipleImages[typeId]!!.shuffled()
            if (images.size >= 2) {
                val typeInfo = manifest.types[typeId]
                questions.add(QuizQuestion(
                    image1Path = images[0],
                    image2Path = images[1],
                    type1 = typeId,
                    type2 = typeId,
                    type1DisplayName = typeInfo?.displayName ?: typeId,
                    type2DisplayName = typeInfo?.displayName ?: typeId,
                    isSame = true
                ))
            }
        }
        
        // 異なる種類の問題を生成（similar_pairsを優先）
        val usedPairs = mutableSetOf<Pair<String, String>>()
        for (pair in manifest.similarPairs.shuffled()) {
            if (questions.size >= count) break
            val images1 = imagesByType[pair.id1] ?: continue
            val images2 = imagesByType[pair.id2] ?: continue
            if (images1.isEmpty() || images2.isEmpty()) continue
            
            val pairKey = if (pair.id1 < pair.id2) Pair(pair.id1, pair.id2) else Pair(pair.id2, pair.id1)
            if (pairKey in usedPairs) continue
            usedPairs.add(pairKey)
            
            val type1Info = manifest.types[pair.id1]
            val type2Info = manifest.types[pair.id2]
            questions.add(QuizQuestion(
                image1Path = images1.random(),
                image2Path = images2.random(),
                type1 = pair.id1,
                type2 = pair.id2,
                type1DisplayName = type1Info?.displayName ?: pair.id1,
                type2DisplayName = type2Info?.displayName ?: pair.id2,
                isSame = false
            ))
        }
        
        // まだ足りない場合はランダムに組み合わせ
        val typeIds = imagesByType.keys.toList()
        while (questions.size < count && typeIds.size >= 2) {
            val type1 = typeIds.random()
            val type2 = typeIds.filter { it != type1 }.random()
            val images1 = imagesByType[type1] ?: continue
            val images2 = imagesByType[type2] ?: continue
            
            val type1Info = manifest.types[type1]
            val type2Info = manifest.types[type2]
            questions.add(QuizQuestion(
                image1Path = images1.random(),
                image2Path = images2.random(),
                type1 = type1,
                type2 = type2,
                type1DisplayName = type1Info?.displayName ?: type1,
                type2DisplayName = type2Info?.displayName ?: type2,
                isSame = false
            ))
        }
        
        return questions.shuffled().take(count)
    }
}
