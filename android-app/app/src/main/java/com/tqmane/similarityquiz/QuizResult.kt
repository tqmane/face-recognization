package com.tqmane.similarityquiz

import java.io.Serializable

/**
 * クイズの各問題の結果を保持するデータクラス
 */
data class QuizResult(
    val questionNumber: Int,
    val imagePath: String,
    val isSame: Boolean,
    val userAnswer: Boolean,
    val isCorrect: Boolean,
    val responseTimeMs: Long
) : Serializable
