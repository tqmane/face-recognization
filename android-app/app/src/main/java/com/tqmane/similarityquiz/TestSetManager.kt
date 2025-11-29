package com.tqmane.similarityquiz

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

/**
 * テストセットの保存・読み込み管理
 * 事前にダウンロードした画像セットを保存して再利用可能
 */
class TestSetManager(private val context: Context) {

    companion object {
        private const val TEST_SET_DIR = "test_sets"
        private const val METADATA_FILE = "metadata.txt"
        private const val DEFAULT_SET_SIZE = 200
    }

    private val quizManager = OnlineQuizManager()

    /**
     * テストセット情報
     */
    data class TestSetInfo(
        val name: String,
        val genre: OnlineQuizManager.Genre,
        val questionCount: Int,
        val createdAt: Long,
        val dirPath: String
    )

    /**
     * 保存された問題データ
     */
    data class SavedQuestion(
        val index: Int,
        val isSame: Boolean,
        val description: String,
        val imagePath: String
    )

    /**
     * 利用可能なテストセット一覧を取得
     */
    fun getAvailableTestSets(): List<TestSetInfo> {
        val baseDir = File(context.filesDir, TEST_SET_DIR)
        if (!baseDir.exists()) return emptyList()

        return baseDir.listFiles()?.mapNotNull { dir ->
            if (dir.isDirectory) {
                parseTestSetInfo(dir)
            } else null
        }?.sortedByDescending { it.createdAt } ?: emptyList()
    }

    private fun parseTestSetInfo(dir: File): TestSetInfo? {
        val metadataFile = File(dir, METADATA_FILE)
        if (!metadataFile.exists()) return null

        return try {
            val lines = metadataFile.readLines()
            val genreName = lines.getOrNull(0) ?: return null
            val count = lines.getOrNull(1)?.toIntOrNull() ?: return null
            val createdAt = lines.getOrNull(2)?.toLongOrNull() ?: System.currentTimeMillis()

            TestSetInfo(
                name = dir.name,
                genre = OnlineQuizManager.Genre.valueOf(genreName),
                questionCount = count,
                createdAt = createdAt,
                dirPath = dir.absolutePath
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * テストセットを作成（並列ダウンロード）
     * @param genre ジャンル
     * @param totalQuestions 問題数（デフォルト200）
     * @param onProgress 進捗コールバック (current, total)
     * @return 成功した問題数
     */
    suspend fun createTestSet(
        genre: OnlineQuizManager.Genre,
        totalQuestions: Int = DEFAULT_SET_SIZE,
        onProgress: (Int, Int) -> Unit
    ): Int = withContext(Dispatchers.IO) {
        // 保存先ディレクトリ
        val timestamp = System.currentTimeMillis()
        val setName = "${genre.displayName}_${timestamp}"
        val setDir = File(context.filesDir, "$TEST_SET_DIR/$setName")
        setDir.mkdirs()

        // 使用済みURLをクリア
        quizManager.scraper.clearUsedUrls()

        // 問題設定を事前に生成（余裕を持って多めに）
        val questionConfigs = (0 until totalQuestions * 3).map { index ->
            index to quizManager.generateRandomQuestion(genre)
        }

        var successCount = 0
        var configIndex = 0
        val savedQuestions = mutableListOf<SavedQuestion>()

        // 20問ずつ並列ダウンロード
        val batchSize = 20

        while (successCount < totalQuestions && configIndex < questionConfigs.size) {
            val remaining = totalQuestions - successCount
            val currentBatch = minOf(batchSize, remaining, questionConfigs.size - configIndex)
            
            val batch = questionConfigs.subList(configIndex, configIndex + currentBatch)
            configIndex += currentBatch

            // 並列ダウンロード（各問題にインデックス付与で混ざらない）
            val results = batch.map { (originalIndex, config) ->
                async {
                    try {
                        val bitmap = if (config.isSame) {
                            quizManager.scraper.createSameImage(config.query1)
                        } else {
                            quizManager.scraper.createComparisonImage(config.query1, config.query2)
                        }
                        
                        if (bitmap != null) {
                            Triple(originalIndex, config, bitmap)
                        } else null
                    } catch (e: Exception) {
                        null
                    }
                }
            }.awaitAll().filterNotNull()

            // 保存
            for ((_, config, bitmap) in results) {
                if (successCount >= totalQuestions) break
                
                val questionIndex = successCount
                val imagePath = "question_${questionIndex}.png"
                val imageFile = File(setDir, imagePath)
                
                try {
                    FileOutputStream(imageFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                    }
                    bitmap.recycle()
                    
                    savedQuestions.add(SavedQuestion(
                        index = questionIndex,
                        isSame = config.isSame,
                        description = config.description,
                        imagePath = imagePath
                    ))
                    
                    successCount++
                    onProgress(successCount, totalQuestions)
                } catch (e: Exception) {
                    // 保存失敗は無視
                }
            }
        }

        // メタデータ保存
        if (successCount > 0) {
            saveMetadata(setDir, genre, successCount, timestamp, savedQuestions)
        } else {
            // 失敗したらディレクトリ削除
            setDir.deleteRecursively()
        }

        // スクレイパーのキャッシュクリア
        quizManager.scraper.clearCache()

        successCount
    }

    private fun saveMetadata(
        setDir: File,
        genre: OnlineQuizManager.Genre,
        count: Int,
        timestamp: Long,
        questions: List<SavedQuestion>
    ) {
        // メタデータファイル
        val metadataFile = File(setDir, METADATA_FILE)
        metadataFile.writeText("${genre.name}\n$count\n$timestamp")

        // 問題データファイル
        val questionsFile = File(setDir, "questions.txt")
        val questionsData = questions.joinToString("\n") { q ->
            "${q.index}|${q.isSame}|${q.description}|${q.imagePath}"
        }
        questionsFile.writeText(questionsData)
    }

    /**
     * テストセットから問題を読み込む
     */
    fun loadTestSet(testSetInfo: TestSetInfo): List<SavedQuestion> {
        val questionsFile = File(testSetInfo.dirPath, "questions.txt")
        if (!questionsFile.exists()) return emptyList()

        return try {
            questionsFile.readLines().mapNotNull { line ->
                val parts = line.split("|")
                if (parts.size >= 4) {
                    SavedQuestion(
                        index = parts[0].toIntOrNull() ?: return@mapNotNull null,
                        isSame = parts[1].toBoolean(),
                        description = parts[2],
                        imagePath = parts[3]
                    )
                } else null
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * 画像を読み込み
     */
    fun loadQuestionImage(testSetInfo: TestSetInfo, question: SavedQuestion): Bitmap? {
        val imageFile = File(testSetInfo.dirPath, question.imagePath)
        return if (imageFile.exists()) {
            BitmapFactory.decodeFile(imageFile.absolutePath)
        } else null
    }
    
    /**
     * テストセットから画像付き問題を読み込む（指定数まで）
     */
    data class LoadedQuestion(
        val bitmap: Bitmap,
        val isSame: Boolean,
        val description: String
    )
    
    fun loadQuestionsFromTestSet(dirPath: String, maxCount: Int): List<LoadedQuestion> {
        val questionsFile = File(dirPath, "questions.txt")
        if (!questionsFile.exists()) return emptyList()
        
        val result = mutableListOf<LoadedQuestion>()
        
        try {
            val lines = questionsFile.readLines().shuffled() // シャッフルして多様性を確保
            
            for (line in lines) {
                if (result.size >= maxCount) break
                
                val parts = line.split("|")
                if (parts.size >= 4) {
                    val imagePath = parts[3]
                    val imageFile = File(dirPath, imagePath)
                    
                    if (imageFile.exists()) {
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                        if (bitmap != null) {
                            result.add(LoadedQuestion(
                                bitmap = bitmap,
                                isSame = parts[1].toBoolean(),
                                description = parts[2]
                            ))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // エラー時は空リストを返す
        }
        
        return result
    }

    /**
     * テストセットを削除
     */
    fun deleteTestSet(testSetInfo: TestSetInfo): Boolean {
        return try {
            File(testSetInfo.dirPath).deleteRecursively()
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 全テストセットの合計サイズを取得（MB）
     */
    fun getTotalStorageUsed(): Double {
        val baseDir = File(context.filesDir, TEST_SET_DIR)
        if (!baseDir.exists()) return 0.0
        
        var totalSize = 0L
        baseDir.walkTopDown().forEach { file ->
            if (file.isFile) {
                totalSize += file.length()
            }
        }
        
        return totalSize / (1024.0 * 1024.0)
    }
}
