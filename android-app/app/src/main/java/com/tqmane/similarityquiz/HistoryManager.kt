package com.tqmane.similarityquiz

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.Serializable

/**
 * 各問題の結果を保持するデータクラス（履歴用）
 */
data class QuestionResultData(
    val questionNumber: Int,
    val description: String,
    val isCorrect: Boolean,
    val wasSame: Boolean,
    val answeredSame: Boolean
) : Serializable {
    fun toJson(): JSONObject = JSONObject().apply {
        put("questionNumber", questionNumber)
        put("description", description)
        put("isCorrect", isCorrect)
        put("wasSame", wasSame)
        put("answeredSame", answeredSame)
    }

    companion object {
        fun fromJson(json: JSONObject): QuestionResultData = QuestionResultData(
            questionNumber = json.getInt("questionNumber"),
            description = json.optString("description", ""),
            isCorrect = json.getBoolean("isCorrect"),
            wasSame = json.getBoolean("wasSame"),
            answeredSame = json.getBoolean("answeredSame")
        )
    }
}

/**
 * クイズ履歴を保持するデータクラス
 */
data class QuizHistoryData(
    val id: String,
    val genre: String,
    val responderName: String,
    val score: Int,
    val total: Int,
    val timeMillis: Long,
    val timestamp: Long,
    val questionResults: List<QuestionResultData>
) : Serializable {
    val accuracy: Double get() = if (total > 0) score.toDouble() / total * 100 else 0.0

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("genre", genre)
        put("responderName", responderName)
        put("score", score)
        put("total", total)
        put("timeMillis", timeMillis)
        put("timestamp", timestamp)
        put("questionResults", JSONArray().apply {
            questionResults.forEach { put(it.toJson()) }
        })
    }

    companion object {
        fun fromJson(json: JSONObject): QuizHistoryData = QuizHistoryData(
            id = json.getString("id"),
            genre = json.getString("genre"),
            responderName = json.optString("responderName", ""),
            score = json.getInt("score"),
            total = json.getInt("total"),
            timeMillis = json.getLong("timeMillis"),
            timestamp = json.getLong("timestamp"),
            questionResults = json.optJSONArray("questionResults")?.let { arr ->
                (0 until arr.length()).map { QuestionResultData.fromJson(arr.getJSONObject(it)) }
            } ?: emptyList()
        )
    }
}

/**
 * ジャンル/回答者ごとの統計
 */
data class GenreStats(
    val name: String,
    val totalTests: Int,
    val totalQuestions: Int,
    val totalCorrect: Int,
    val totalTimeMillis: Long,
    val averageAccuracy: Double,
    val averageScore: Double,
    val averageTime: Double
) {
    companion object {
        fun fromHistories(name: String, histories: List<QuizHistoryData>): GenreStats {
            if (histories.isEmpty()) {
                return GenreStats(name, 0, 0, 0, 0, 0.0, 0.0, 0.0)
            }

            var totalQuestions = 0
            var totalCorrect = 0
            var totalTimeMillis = 0L

            for (h in histories) {
                totalQuestions += h.total
                totalCorrect += h.score
                totalTimeMillis += h.timeMillis
            }

            return GenreStats(
                name = name,
                totalTests = histories.size,
                totalQuestions = totalQuestions,
                totalCorrect = totalCorrect,
                totalTimeMillis = totalTimeMillis,
                averageAccuracy = if (totalQuestions > 0) totalCorrect.toDouble() / totalQuestions * 100 else 0.0,
                averageScore = totalCorrect.toDouble() / histories.size,
                averageTime = totalTimeMillis.toDouble() / histories.size
            )
        }
    }
}

/**
 * 履歴管理クラス
 */
class HistoryManager private constructor(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val histories: MutableList<QuizHistoryData> = mutableListOf()
    private val responderNames: MutableList<String> = mutableListOf()

    init {
        loadHistories()
        loadResponderNames()
    }

    private fun loadHistories() {
        val jsonStr = prefs.getString(KEY_HISTORIES, null) ?: return
        try {
            val arr = JSONArray(jsonStr)
            histories.clear()
            for (i in 0 until arr.length()) {
                histories.add(QuizHistoryData.fromJson(arr.getJSONObject(i)))
            }
            // 新しい順にソート
            histories.sortByDescending { it.timestamp }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun loadResponderNames() {
        val jsonStr = prefs.getString(KEY_RESPONDER_NAMES, null) ?: return
        try {
            val arr = JSONArray(jsonStr)
            responderNames.clear()
            for (i in 0 until arr.length()) {
                responderNames.add(arr.getString(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun getHistories(): List<QuizHistoryData> = histories.toList()
    
    fun getRecentResponderNames(): List<String> = responderNames.toList()

    fun saveHistory(history: QuizHistoryData) {
        histories.add(0, history)
        
        // 回答者名を履歴に追加
        if (history.responderName.isNotEmpty()) {
            addResponderName(history.responderName)
        }
        
        persist()
    }
    
    /**
     * 回答者名を履歴に追加
     */
    fun addResponderName(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        
        // 既に存在する場合は削除して先頭に追加
        responderNames.remove(trimmed)
        responderNames.add(0, trimmed)
        
        // 最大8件まで保持
        while (responderNames.size > MAX_RESPONDER_NAMES) {
            responderNames.removeAt(responderNames.lastIndex)
        }
        
        persistResponderNames()
    }
    
    /**
     * 回答者名を履歴から削除
     */
    fun removeResponderName(name: String) {
        responderNames.remove(name)
        persistResponderNames()
    }
    
    private fun persistResponderNames() {
        val arr = JSONArray()
        responderNames.forEach { arr.put(it) }
        prefs.edit().putString(KEY_RESPONDER_NAMES, arr.toString()).apply()
    }

    private fun persist() {
        val arr = JSONArray()
        histories.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(KEY_HISTORIES, arr.toString()).apply()
    }

    fun clearHistories() {
        histories.clear()
        prefs.edit().remove(KEY_HISTORIES).apply()
    }

    /**
     * 指定したIDの履歴を削除
     */
    fun deleteHistory(id: String) {
        histories.removeAll { it.id == id }
        persist()
    }
    
    /**
     * 指定した複数のIDの履歴を削除
     */
    fun deleteHistories(ids: Set<String>) {
        histories.removeAll { it.id in ids }
        persist()
    }

    fun getStatsByGenre(): Map<String, GenreStats> {
        val grouped = histories.groupBy { it.genre }
        return grouped.mapValues { (genre, list) -> GenreStats.fromHistories(genre, list) }
    }

    fun getOverallStats(): GenreStats {
        return GenreStats.fromHistories("全体", histories)
    }

    fun getStatsByResponder(): Map<String, GenreStats> {
        val grouped = histories.groupBy { if (it.responderName.isEmpty()) "匿名" else it.responderName }
        return grouped.mapValues { (name, list) -> GenreStats.fromHistories(name, list) }
    }

    fun getResponders(): List<String> {
        return histories.map { if (it.responderName.isEmpty()) "匿名" else it.responderName }.distinct().sorted()
    }

    companion object {
        private const val PREFS_NAME = "quiz_history"
        private const val KEY_HISTORIES = "histories"
        private const val KEY_RESPONDER_NAMES = "responder_names"
        private const val MAX_RESPONDER_NAMES = 8

        @Volatile
        private var instance: HistoryManager? = null

        fun getInstance(context: Context): HistoryManager {
            return instance ?: synchronized(this) {
                instance ?: HistoryManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
