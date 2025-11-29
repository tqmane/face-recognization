package com.example.similarityquiz

import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.example.similarityquiz.databinding.ActivityOnlineQuizBinding
import kotlinx.coroutines.launch
import java.util.Timer
import kotlin.concurrent.fixedRateTimer

/**
 * オンラインモードのクイズ画面
 * 事前に全画像を取得してからテスト開始
 */
class OnlineQuizActivity : AppCompatActivity() {

    private lateinit var binding: ActivityOnlineQuizBinding
    private val quizManager = OnlineQuizManager()
    
    // 事前に準備した問題リスト
    private val preparedQuestions = mutableListOf<PreparedQuestion>()
    
    private var currentQuestionIndex = 0
    private var score = 0
    private var totalQuestions = 10
    
    private var startTime = 0L
    private var questionStartTime = 0L
    private var timer: Timer? = null
    
    private val results = mutableListOf<QuizResult>()

    data class PreparedQuestion(
        val bitmap: Bitmap,
        val isSame: Boolean,
        val description: String
    )

    private var selectedGenre = OnlineQuizManager.Genre.ALL

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityOnlineQuizBinding.inflate(layoutInflater)
        setContentView(binding.root)

        totalQuestions = intent.getIntExtra("total_questions", 10)
        
        // ジャンルを取得
        val genreName = intent.getStringExtra("genre")
        selectedGenre = try {
            OnlineQuizManager.Genre.valueOf(genreName ?: "ALL")
        } catch (e: Exception) {
            OnlineQuizManager.Genre.ALL
        }
        
        setupButtons()
        prepareAllQuestions()
    }

    private fun setupButtons() {
        binding.btnSame.setOnClickListener {
            checkAnswer(true)
        }

        binding.btnDifferent.setOnClickListener {
            checkAnswer(false)
        }
    }

    /**
     * 全問題の画像を事前にダウンロード
     */
    private fun prepareAllQuestions() {
        // ローディング表示
        binding.progressLoading.visibility = View.VISIBLE
        binding.ivQuizImage.visibility = View.INVISIBLE
        binding.btnSame.isEnabled = false
        binding.btnDifferent.isEnabled = false
        binding.tvFeedback.visibility = View.INVISIBLE
        binding.tvLoadingText.visibility = View.VISIBLE
        binding.tvProgress.text = "準備中..."
        binding.tvScore.text = "${selectedGenre.displayName}"

        lifecycleScope.launch {
            preparedQuestions.clear()
            var successCount = 0
            var attemptCount = 0
            val maxAttempts = totalQuestions * 3 // 失敗を考慮して多めに試行

            while (successCount < totalQuestions && attemptCount < maxAttempts) {
                attemptCount++
                
                // 進捗を更新
                runOnUiThread {
                    binding.tvLoadingText.text = "画像を準備中... ($successCount / $totalQuestions)"
                }

                try {
                    // 選択したジャンルから問題を生成
                    val questionConfig = quizManager.generateRandomQuestion(selectedGenre)
                    
                    val bitmap = if (questionConfig.isSame) {
                        quizManager.scraper.createSameImage(questionConfig.query1)
                    } else {
                        quizManager.scraper.createComparisonImage(questionConfig.query1, questionConfig.query2)
                    }

                    if (bitmap != null) {
                        preparedQuestions.add(
                            PreparedQuestion(
                                bitmap = bitmap,
                                isSame = questionConfig.isSame,
                                description = questionConfig.description
                            )
                        )
                        successCount++
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            runOnUiThread {
                if (preparedQuestions.size >= 3) {
                    // 最低3問あればテスト開始
                    totalQuestions = preparedQuestions.size
                    startQuiz()
                } else {
                    Toast.makeText(
                        this@OnlineQuizActivity,
                        "画像の取得に失敗しました。ネットワークを確認してください。",
                        Toast.LENGTH_LONG
                    ).show()
                    finish()
                }
            }
        }
    }

    /**
     * テスト開始（画像準備完了後）
     */
    private fun startQuiz() {
        score = 0
        currentQuestionIndex = 0
        results.clear()
        
        // 問題をシャッフル
        preparedQuestions.shuffle()
        
        // ローディング非表示
        binding.progressLoading.visibility = View.GONE
        binding.tvLoadingText.visibility = View.GONE
        
        // タイマー開始（ここからが本当の計測開始）
        startTime = System.currentTimeMillis()
        timer = fixedRateTimer(period = 100) {
            runOnUiThread {
                val elapsed = System.currentTimeMillis() - startTime
                binding.tvTimer.text = formatTime(elapsed)
            }
        }
        
        showQuestion()
    }

    private fun showQuestion() {
        if (currentQuestionIndex >= preparedQuestions.size) {
            finishQuiz()
            return
        }

        val question = preparedQuestions[currentQuestionIndex]
        questionStartTime = System.currentTimeMillis()

        // UI更新
        binding.tvProgress.text = "問題 ${currentQuestionIndex + 1} / ${preparedQuestions.size}"
        binding.tvScore.text = "$score 点"
        binding.ivQuizImage.setImageBitmap(question.bitmap)
        binding.ivQuizImage.visibility = View.VISIBLE
        binding.tvFeedback.visibility = View.INVISIBLE
        binding.btnSame.isEnabled = true
        binding.btnDifferent.isEnabled = true
    }

    private fun checkAnswer(userAnsweredSame: Boolean) {
        val question = preparedQuestions[currentQuestionIndex]
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
                imagePath = question.description,
                isSame = question.isSame,
                userAnswer = userAnsweredSame,
                isCorrect = isCorrect,
                responseTimeMs = responseTime
            )
        )

        binding.btnSame.isEnabled = false
        binding.btnDifferent.isEnabled = false

        currentQuestionIndex++

        // 1秒後に次の問題へ
        binding.root.postDelayed({
            showQuestion()
        }, 1000)
    }

    private fun finishQuiz() {
        timer?.cancel()
        val totalTime = System.currentTimeMillis() - startTime

        // ベストスコアを更新
        val prefs = getSharedPreferences("quiz_prefs", MODE_PRIVATE)
        val bestScore = prefs.getInt("best_score_online", 0)
        
        if (score > bestScore) {
            prefs.edit()
                .putInt("best_score_online", score)
                .putLong("best_time_online", totalTime)
                .apply()
        }

        // 結果画面へ
        val intent = Intent(this, ResultActivity::class.java).apply {
            putExtra("score", score)
            putExtra("total_questions", preparedQuestions.size)
            putExtra("total_time", totalTime)
            putExtra("results", ArrayList(results))
            putExtra("mode", "online")
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
        timer?.cancel()
    }
}
