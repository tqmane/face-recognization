package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivityZipQuizBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Timer
import kotlin.concurrent.fixedRateTimer

/**
 * ZIPテストセット用のクイズ画面
 * 2枚の画像を別々に表示し、同じ種類か違う種類かを判定
 */
class ZipQuizActivity : AppCompatActivity() {

    private lateinit var binding: ActivityZipQuizBinding
    private lateinit var historyManager: HistoryManager
    private lateinit var zipService: ZipTestSetService
    
    private var questions: List<ZipTestSetService.QuizQuestion> = emptyList()
    private var currentIndex = 0
    private var score = 0
    
    private var startTime = 0L
    private var timer: Timer? = null
    
    private var testSetId: String = ""
    private var testSetName: String = ""
    private var questionCount: Int = 10
    private var responderName: String = ""
    
    private val questionResults = mutableListOf<QuestionResultData>()
    private val resultsForUi = mutableListOf<QuizResult>()
    private var questionStartTimeMs: Long = 0L

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val (height, width) = options.outHeight to options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            var halfHeight = height / 2
            var halfWidth = width / 2

            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }

        return inSampleSize.coerceAtLeast(1)
    }

    private fun decodeScaledBitmap(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds, reqWidth, reqHeight)
            inPreferredConfig = Bitmap.Config.RGB_565
            inDither = true
        }
        return BitmapFactory.decodeFile(path, options)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityZipQuizBinding.inflate(layoutInflater)
        setContentView(binding.root)

        historyManager = HistoryManager.getInstance(this)
        zipService = ZipTestSetService(this)
        
        testSetId = intent.getStringExtra("test_set_id") ?: ""
        testSetName = intent.getStringExtra("test_set_name") ?: ""
        questionCount = intent.getIntExtra("question_count", 10)
        
        if (testSetId.isEmpty()) {
            finish()
            return
        }
        
        binding.toolbar.setNavigationOnClickListener { 
            showExitConfirmDialog()
        }
        
        binding.btnSame.setOnClickListener { answer(true) }
        binding.btnDifferent.setOnClickListener { answer(false) }
        
        showNameInputDialog()
    }
    
    private fun showNameInputDialog() {
        val density = resources.displayMetrics.density
        val paddingH = (16 * density).toInt()
        val paddingV = (12 * density).toInt()
        val input = EditText(this).apply {
            hint = "入力しなくても大丈夫です"
            setPadding(paddingH, paddingV, paddingH, paddingV)
        }
        
        // 履歴から候補を取得
        val recentNames = historyManager.getRecentResponderNames()
        
        if (recentNames.isNotEmpty()) {
            MaterialAlertDialogBuilder(this)
                .setTitle("回答者名")
                .setView(input)
                .setPositiveButton("開始") { _, _ ->
                    responderName = input.text.toString().trim()
                    startQuiz()
                }
                .setNeutralButton("履歴から選択") { _, _ ->
                    showNameHistoryDialog()
                }
                .setNegativeButton("キャンセル") { _, _ -> finish() }
                .setCancelable(false)
                .show()
        } else {
            MaterialAlertDialogBuilder(this)
                .setTitle("回答者名")
                .setView(input)
                .setPositiveButton("開始") { _, _ ->
                    responderName = input.text.toString().trim()
                    startQuiz()
                }
                .setNegativeButton("キャンセル") { _, _ -> finish() }
                .setCancelable(false)
                .show()
        }
    }
    
    private fun showNameHistoryDialog() {
        val names = historyManager.getRecentResponderNames()
        
        MaterialAlertDialogBuilder(this)
            .setTitle("回答者を選択")
            .setItems(names.toTypedArray()) { _, which ->
                responderName = names[which]
                startQuiz()
            }
            .setNegativeButton("戻る") { _, _ ->
                showNameInputDialog()
            }
            .setCancelable(false)
            .show()
    }
    
    private fun startQuiz() {
        questions = zipService.generateQuestions(testSetId, questionCount)
        
        if (questions.isEmpty()) {
            MaterialAlertDialogBuilder(this)
                .setTitle("エラー")
                .setMessage("問題を生成できませんでした")
                .setPositiveButton("OK") { _, _ -> finish() }
                .show()
            return
        }
        
        binding.toolbar.title = testSetName
        
        // カウントダウン
        showCountdown()
    }
    
    private fun showCountdown() {
        binding.layoutCountdown.visibility = View.VISIBLE
        binding.layoutQuiz.visibility = View.GONE
        
        var count = 3
        binding.tvCountdown.text = count.toString()
        
        val countdownTimer = fixedRateTimer(period = 1000) {
            runOnUiThread {
                count--
                if (count > 0) {
                    binding.tvCountdown.text = count.toString()
                } else {
                    this.cancel()
                    binding.layoutCountdown.visibility = View.GONE
                    binding.layoutQuiz.visibility = View.VISIBLE
                    startTime = System.currentTimeMillis()
                    startTimer()
                    showQuestion()
                }
            }
        }
    }
    
    private fun startTimer() {
        timer = fixedRateTimer(period = 100) {
            runOnUiThread {
                val elapsed = System.currentTimeMillis() - startTime
                val seconds = elapsed / 1000
                val minutes = seconds / 60
                val secs = seconds % 60
                binding.tvTimer.text = String.format("%d:%02d", minutes, secs)
            }
        }
    }
    
    private fun showQuestion() {
        val question = questions[currentIndex]
        
        // 進捗更新
        binding.tvProgress.text = "${currentIndex + 1} / ${questions.size}"
        binding.progressBar.max = questions.size
        binding.progressBar.progress = currentIndex + 1
        binding.tvScore.text = "正解: $score"
        
        // 画像を読み込み
        try {
            val w1 = binding.ivImage1.width.takeIf { it > 0 } ?: 900
            val h1 = binding.ivImage1.height.takeIf { it > 0 } ?: 900
            val w2 = binding.ivImage2.width.takeIf { it > 0 } ?: 900
            val h2 = binding.ivImage2.height.takeIf { it > 0 } ?: 900

            binding.ivImage1.setImageBitmap(decodeScaledBitmap(question.image1Path, w1, h1))
            binding.ivImage2.setImageBitmap(decodeScaledBitmap(question.image2Path, w2, h2))
        } catch (e: Exception) {
            e.printStackTrace()
        }

        questionStartTimeMs = System.currentTimeMillis()
        
        // ボタンを有効化
        binding.btnSame.isEnabled = true
        binding.btnDifferent.isEnabled = true
    }
    
    private fun answer(answeredSame: Boolean) {
        binding.btnSame.isEnabled = false
        binding.btnDifferent.isEnabled = false
        
        val question = questions[currentIndex]
        val isCorrect = (answeredSame == question.isSame)
        val responseTimeMs = (System.currentTimeMillis() - questionStartTimeMs).coerceAtLeast(0L)
        
        if (isCorrect) {
            score++
        }
        
        // 結果を記録
        questionResults.add(QuestionResultData(
            questionNumber = currentIndex + 1,
            description = question.description,
            isCorrect = isCorrect,
            wasSame = question.isSame,
            answeredSame = answeredSame
        ))
        resultsForUi.add(
            QuizResult(
                questionNumber = currentIndex + 1,
                imagePath = question.description,
                isSame = question.isSame,
                userAnswer = answeredSame,
                isCorrect = isCorrect,
                responseTimeMs = responseTimeMs,
            )
        )
        
        // フィードバック表示
        showFeedback(isCorrect) {
            if (currentIndex < questions.size - 1) {
                currentIndex++
                showQuestion()
            } else {
                finishQuiz()
            }
        }
    }
    
    private fun showFeedback(isCorrect: Boolean, onComplete: () -> Unit) {
        // フィードバック中はタイマーを一時停止
        timer?.cancel()
        
        binding.layoutFeedback.visibility = View.VISIBLE
        binding.tvFeedback.text = if (isCorrect) "○" else "×"
        binding.tvFeedback.setTextColor(
            if (isCorrect) getColor(android.R.color.holo_green_dark) 
            else getColor(android.R.color.holo_red_dark)
        )
        
        binding.layoutFeedback.postDelayed({
            binding.layoutFeedback.visibility = View.GONE
            // タイマーを再開
            startTimer()
            onComplete()
        }, 800)
    }
    
    private fun finishQuiz() {
        timer?.cancel()
        
        val totalTime = System.currentTimeMillis() - startTime
        
        // 履歴に保存
        val historyId = System.currentTimeMillis().toString()
        val historyData = QuizHistoryData(
            id = historyId,
            genre = testSetName,
            responderName = responderName,
            score = score,
            total = questions.size,
            timeMillis = totalTime,
            timestamp = System.currentTimeMillis(),
            questionResults = questionResults
        )
        
        historyManager.saveHistory(historyData)
        
        // Firebase同期
        lifecycleScope.launch(Dispatchers.IO) {
            FirebaseSyncManager.getInstance(this@ZipQuizActivity).uploadHistory(historyData)
        }
        
        // 結果画面へ
        val intent = android.content.Intent(this, ResultActivity::class.java).apply {
            putExtra("mode", "zip")
            putExtra("score", score)
            putExtra("total_questions", questions.size)
            putExtra("total_time", totalTime)
            putExtra("results", ArrayList(resultsForUi))
            putExtra("genre", testSetName)
            putExtra("responder_name", responderName)
            putExtra("history_id", historyId)
        }
        startActivity(intent)
        finish()
    }
    
    private fun showExitConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("テスト中断")
            .setMessage("テストを中断しますか？\n進捗は保存されません。")
            .setPositiveButton("中断する") { _, _ -> 
                timer?.cancel()
                finish() 
            }
            .setNegativeButton("続ける", null)
            .show()
    }
    
    override fun onBackPressed() {
        showExitConfirmDialog()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
    }
}
