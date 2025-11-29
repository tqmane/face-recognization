package com.example.similarityquiz

import android.content.Context

/**
 * クイズの問題を管理するクラス
 */
class QuizManager(private val context: Context) {

    private val questions = mutableListOf<QuizQuestion>()

    init {
        loadQuestions()
    }

    private fun loadQuestions() {
        questions.clear()
        
        // assetsフォルダから画像を読み込む
        // same/ フォルダ: 同じもの同士
        // different/ フォルダ: 違うもの同士
        
        try {
            // same/ フォルダの画像（正解は「同じ」）
            context.assets.list("same")?.forEach { filename ->
                if (filename.endsWith(".jpg") || filename.endsWith(".png")) {
                    questions.add(QuizQuestion("same/$filename", true))
                }
            }

            // different/ フォルダの画像（正解は「違う」）
            context.assets.list("different")?.forEach { filename ->
                if (filename.endsWith(".jpg") || filename.endsWith(".png")) {
                    questions.add(QuizQuestion("different/$filename", false))
                }
            }
        } catch (e: Exception) {
            // assetsフォルダがない場合はサンプル問題を追加
        }

        // 画像がない場合はサンプル問題を追加
        if (questions.isEmpty()) {
            addSampleQuestions()
        }

        // シャッフル
        questions.shuffle()
    }

    private fun addSampleQuestions() {
        // サンプル問題（実際の画像がない場合用）
        // 実際に使う時は assets/same/ と assets/different/ に画像を配置
        questions.add(QuizQuestion("sample/sample1.jpg", true))
        questions.add(QuizQuestion("sample/sample2.jpg", false))
        questions.add(QuizQuestion("sample/sample3.jpg", true))
        questions.add(QuizQuestion("sample/sample4.jpg", false))
        questions.add(QuizQuestion("sample/sample5.jpg", true))
    }

    fun getQuestions(): List<QuizQuestion> = questions

    fun getTotalQuestions(): Int = questions.size
}

/**
 * クイズの問題データ
 */
data class QuizQuestion(
    val imagePath: String,  // assets内のパス
    val isSame: Boolean     // true: 同じもの, false: 違うもの
)
