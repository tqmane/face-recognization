package com.tqmane.similarityquiz

import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.tqmane.similarityquiz.databinding.ActivityOnlineQuizBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import java.util.Timer
import kotlin.concurrent.fixedRateTimer

/**
 * オンラインモードのクイズ画面
 * 事前に全画像を取得してからテスト開始（並列高速版）
 */
class OnlineQuizActivity : AppCompatActivity() {

    private lateinit var binding: ActivityOnlineQuizBinding
    private lateinit var historyManager: HistoryManager
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
    private val questionResultsForHistory = mutableListOf<QuestionResultData>()
    
    private var selectedGenre = OnlineQuizManager.Genre.ALL
    private var downloadJob: Job? = null
    private var isCancelled = false
    
    // 回答者名
    private var responderName = ""

    data class PreparedQuestion(
        val bitmap: Bitmap,
        val isSame: Boolean,
        val description: String
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityOnlineQuizBinding.inflate(layoutInflater)
        setContentView(binding.root)

        historyManager = HistoryManager.getInstance(this)
        totalQuestions = intent.getIntExtra("total_questions", 10)
        
        // ジャンルを取得
        val genreName = intent.getStringExtra("genre")
        selectedGenre = try {
            OnlineQuizManager.Genre.valueOf(genreName ?: "ALL")
        } catch (e: Exception) {
            OnlineQuizManager.Genre.ALL
        }
        
        setupButtons()
        showLoadingUI()
        prepareAllQuestions()
    }

    private fun setupButtons() {
        binding.btnSame.setOnClickListener {
            checkAnswer(true)
        }

        binding.btnDifferent.setOnClickListener {
            checkAnswer(false)
        }

        binding.btnCancel.setOnClickListener {
            showCancelConfirmDialog()
        }
    }

    /**
     * ローディング画面を表示
     */
    private fun showLoadingUI() {
        binding.loadingContainer.visibility = View.VISIBLE
        binding.ivQuizImage.visibility = View.INVISIBLE
        binding.tvFeedback.visibility = View.INVISIBLE
        
        // クイズボタンを非表示、キャンセルボタンを表示
        binding.buttonContainer.visibility = View.GONE
        binding.cancelContainer.visibility = View.VISIBLE
        
        // ヘッダー更新
        binding.tvGenre.text = "🌐 ${selectedGenre.displayName}"
        binding.tvProgress.text = "準備中..."
        binding.tvScore.text = ""
        binding.tvTimer.text = "--:--"
        
        // プログレスバー初期化
        binding.progressBar.progress = 0
        binding.tvProgressPercent.text = "0%"
    }

    /**
     * クイズ画面を表示
     */
    private fun showQuizUI() {
        binding.loadingContainer.visibility = View.GONE
        binding.ivQuizImage.visibility = View.VISIBLE
        
        // クイズボタンを表示、キャンセルボタンを非表示
        binding.buttonContainer.visibility = View.VISIBLE
        binding.cancelContainer.visibility = View.GONE
    }

    /**
     * キャンセル確認ダイアログ
     */
    private fun showCancelConfirmDialog() {
        AlertDialog.Builder(this)
            .setTitle("キャンセルしますか？")
            .setMessage("ダウンロード中の画像はすべて破棄されます。\n本当にキャンセルしますか？")
            .setPositiveButton("キャンセルする") { _, _ ->
                cancelDownload()
            }
            .setNegativeButton("続ける", null)
            .show()
    }

    /**
     * ダウンロードをキャンセル
     */
    private fun cancelDownload() {
        isCancelled = true
        downloadJob?.cancel()
        quizManager.scraper.clearCache()
        
        // 準備済み画像をクリア
        preparedQuestions.forEach { it.bitmap.recycle() }
        preparedQuestions.clear()
        
        Toast.makeText(this, "キャンセルしました", Toast.LENGTH_SHORT).show()
        finish()
    }

    /**
     * 全問題の画像を事前にダウンロード（並列高速版）
     */
    private fun prepareAllQuestions() {
        // 新しいテスト開始時に使用済みURLをクリア
        quizManager.scraper.clearUsedUrls()
        
        downloadJob = lifecycleScope.launch {
            preparedQuestions.clear()
            
            // 問題設定を事前に生成（余裕を持って3倍用意）
            val questionConfigs = (0 until totalQuestions * 3).map {
                quizManager.generateRandomQuestion(selectedGenre)
            }
            
            var successCount = 0
            var configIndex = 0
            
            // 順番に処理（並列で5問ずつダウンロード）
            while (successCount < totalQuestions && configIndex < questionConfigs.size && !isCancelled) {
                // 進捗を更新
                val progress = (successCount * 100) / totalQuestions
                runOnUiThread {
                    if (!isCancelled) {
                        binding.tvLoadingText.text = "画像を準備中..."
                        binding.tvLoadingSubtext.text = "$successCount / $totalQuestions 問を取得しました"
                        binding.progressBar.progress = progress
                        binding.tvProgressPercent.text = "$progress%"
                    }
                }

                // 次の5つのconfigを取得
                val batchSize = minOf(5, questionConfigs.size - configIndex)
                val batch = questionConfigs.subList(configIndex, configIndex + batchSize)
                configIndex += batchSize

                // 並列ダウンロード
                val results = batch.map { config ->
                    async {
                        try {
                            val bitmap = if (config.isSame) {
                                quizManager.scraper.createSameImage(config.query1)
                            } else {
                                quizManager.scraper.createComparisonImage(config.query1, config.query2)
                            }
                            if (bitmap != null) {
                                PreparedQuestion(bitmap, config.isSame, config.description)
                            } else null
                        } catch (e: Exception) {
                            null
                        }
                    }
                }.awaitAll().filterNotNull()
                
                // 成功した分だけ追加
                for (result in results) {
                    if (successCount >= totalQuestions || isCancelled) break
                    preparedQuestions.add(result)
                    successCount++
                }
            }

            runOnUiThread {
                if (isCancelled) return@runOnUiThread
                
                if (preparedQuestions.size >= 3) {
                    totalQuestions = preparedQuestions.size
                    showNameInputDialog()
                } else {
                    Toast.makeText(
                        this@OnlineQuizActivity,
                        "画像の取得に失敗しました。\nネットワークを確認してください。",
                        Toast.LENGTH_LONG
                    ).show()
                    finish()
                }
            }
        }
    }
    
    /**
     * 名前入力ダイアログを表示
     */
    private fun showNameInputDialog() {
        val editText = EditText(this).apply {
            hint = "例：山田太郎"
            setPadding(48, 32, 48, 32)
        }
        
        AlertDialog.Builder(this)
            .setTitle("回答者の名前")
            .setMessage("任意入力（スキップ可）")
            .setView(editText)
            .setPositiveButton("開始") { _, _ ->
                responderName = editText.text.toString().trim()
                startQuiz()
            }
            .setNeutralButton("スキップ") { _, _ ->
                responderName = ""
                startQuiz()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * テスト開始（画像準備完了後）
     */
    private fun startQuiz() {
        score = 0
        currentQuestionIndex = 0
        results.clear()
        questionResultsForHistory.clear()
        
        // 問題をシャッフル
        preparedQuestions.shuffle()
        
        // クイズUIに切り替え
        showQuizUI()
        
        // タイマー開始
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
            binding.tvFeedback.text = "🎉 正解！"
            binding.tvFeedback.setTextColor(getColor(R.color.ios_green))
        } else {
            binding.tvFeedback.text = "❌ 不正解"
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
        
        // 履歴用の結果も記録
        questionResultsForHistory.add(
            QuestionResultData(
                questionNumber = currentQuestionIndex + 1,
                description = question.description,
                isCorrect = isCorrect,
                wasSame = question.isSame,
                answeredSame = userAnsweredSame
            )
        )

        binding.btnSame.isEnabled = false
        binding.btnDifferent.isEnabled = false

        currentQuestionIndex++

        // 0.8秒後に次の問題へ（テンポアップ）
        binding.root.postDelayed({
            showQuestion()
        }, 800)
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
        
        // 履歴に保存
        val history = QuizHistoryData(
            id = System.currentTimeMillis().toString(),
            genre = selectedGenre.displayName,
            responderName = responderName,
            score = score / 10,  // 10点刻みなので正解数に変換
            total = totalQuestions,
            timeMillis = totalTime,
            timestamp = System.currentTimeMillis(),
            questionResults = questionResultsForHistory.toList()
        )
        historyManager.saveHistory(history)

        // 画像メモリを解放
        cleanupImages()

        // 結果画面へ
        val intent = Intent(this, ResultActivity::class.java).apply {
            putExtra("score", score)
            putExtra("total_questions", totalQuestions)
            putExtra("total_time", totalTime)
            putExtra("results", ArrayList(results))
            putExtra("mode", "online")
            putExtra("genre", selectedGenre.displayName)
            putExtra("responder_name", responderName)
        }
        startActivity(intent)
        finish()
    }

    /**
     * 画像メモリを解放
     */
    private fun cleanupImages() {
        binding.ivQuizImage.setImageBitmap(null)
        preparedQuestions.forEach { question ->
            if (!question.bitmap.isRecycled) {
                question.bitmap.recycle()
            }
        }
        preparedQuestions.clear()
        quizManager.scraper.clearCache()
    }

    private fun formatTime(millis: Long): String {
        val seconds = millis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        return String.format("%d:%02d", minutes, secs)
    }

    override fun onBackPressed() {
        if (downloadJob?.isActive == true) {
            showCancelConfirmDialog()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
        downloadJob?.cancel()
        cleanupImages()
    }
}
