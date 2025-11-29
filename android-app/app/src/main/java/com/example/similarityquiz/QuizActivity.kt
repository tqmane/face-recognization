package com.example.similarityquiz

import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import com.example.similarityquiz.databinding.ActivityQuizBinding

class QuizActivity : AppCompatActivity() {

    private lateinit var binding: ActivityQuizBinding
    private lateinit var quizManager: QuizManager

    private var currentQuestionIndex = 0
    private var score = 0
    private var startTime = 0L
    private var questionStartTime = 0L

    private val timerHandler = Handler(Looper.getMainLooper())
    private val timerRunnable = object : Runnable {
        override fun run() {
            val elapsed = System.currentTimeMillis() - startTime
            binding.tvTimer.text = "経過時間: ${formatTime(elapsed)}"
            timerHandler.postDelayed(this, 100)
        }
    }

    private val results = mutableListOf<QuizResult>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityQuizBinding.inflate(layoutInflater)
        setContentView(binding.root)

        quizManager = QuizManager(this)
        
        setupButtons()
        startQuiz()
    }

    private fun setupButtons() {
        binding.btnSame.setOnClickListener {
            checkAnswer(true)
        }

        binding.btnDifferent.setOnClickListener {
            checkAnswer(false)
        }
    }

    private fun startQuiz() {
        currentQuestionIndex = 0
        score = 0
        results.clear()
        startTime = System.currentTimeMillis()
        
        // タイマー開始
        timerHandler.post(timerRunnable)
        
        showQuestion()
    }

    private fun showQuestion() {
        val questions = quizManager.getQuestions()
        
        if (currentQuestionIndex >= questions.size) {
            finishQuiz()
            return
        }

        val question = questions[currentQuestionIndex]
        questionStartTime = System.currentTimeMillis()

        // 進捗表示
        binding.tvProgress.text = "問題 ${currentQuestionIndex + 1} / ${questions.size}"
        binding.tvScore.text = "$score 点"

        // 画像を表示
        try {
            val bitmap = assets.open(question.imagePath).use { 
                BitmapFactory.decodeStream(it) 
            }
            binding.ivQuizImage.setImageBitmap(bitmap)
        } catch (e: Exception) {
            // サンプル画像がない場合はプレースホルダーを表示
            binding.ivQuizImage.setImageResource(android.R.drawable.ic_menu_gallery)
        }

        // フィードバックを非表示
        binding.tvFeedback.visibility = View.INVISIBLE

        // ボタンを有効化
        binding.btnSame.isEnabled = true
        binding.btnDifferent.isEnabled = true
    }

    private fun checkAnswer(userAnsweredSame: Boolean) {
        val questions = quizManager.getQuestions()
        val question = questions[currentQuestionIndex]
        val responseTime = System.currentTimeMillis() - questionStartTime

        val isCorrect = (userAnsweredSame == question.isSame)

        if (isCorrect) {
            score += 10
            binding.tvFeedback.text = "正解！"
            binding.tvFeedback.setTextColor(getColor(R.color.ios_green))
        } else {
            binding.tvFeedback.text = "不正解"
            binding.tvFeedback.setTextColor(getColor(R.color.ios_red))
        }

        binding.tvFeedback.visibility = View.VISIBLE
        binding.tvScore.text = "$score 点"

        // 結果を記録
        results.add(
            QuizResult(
                questionNumber = currentQuestionIndex + 1,
                imagePath = question.imagePath,
                isSame = question.isSame,
                userAnswer = userAnsweredSame,
                isCorrect = isCorrect,
                responseTimeMs = responseTime
            )
        )

        // ボタンを一時的に無効化
        binding.btnSame.isEnabled = false
        binding.btnDifferent.isEnabled = false

        // 1秒後に次の問題へ
        Handler(Looper.getMainLooper()).postDelayed({
            currentQuestionIndex++
            showQuestion()
        }, 1000)
    }

    private fun finishQuiz() {
        timerHandler.removeCallbacks(timerRunnable)
        val totalTime = System.currentTimeMillis() - startTime

        // ベストスコアを更新
        val prefs = getSharedPreferences("quiz_prefs", MODE_PRIVATE)
        val bestScore = prefs.getInt("best_score", 0)
        
        if (score > bestScore) {
            prefs.edit()
                .putInt("best_score", score)
                .putLong("best_time", totalTime)
                .apply()
        }

        // 結果画面へ
        val intent = Intent(this, ResultActivity::class.java).apply {
            putExtra("score", score)
            putExtra("total_questions", quizManager.getQuestions().size)
            putExtra("total_time", totalTime)
            putExtra("results", ArrayList(results))
        }
        startActivity(intent)
        finish()
    }

    private fun formatTime(millis: Long): String {
        val seconds = millis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        return String.format("%d:%02d", minutes, secs)
    }

    override fun onDestroy() {
        super.onDestroy()
        timerHandler.removeCallbacks(timerRunnable)
    }
}
