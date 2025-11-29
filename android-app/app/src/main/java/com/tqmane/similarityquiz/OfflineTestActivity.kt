package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.tqmane.similarityquiz.databinding.ActivityOnlineQuizBinding

/**
 * 保存済みテストセットからのクイズ実行
 * OnlineQuizActivityと同様のUI・ロジック
 */
class OfflineTestActivity : AppCompatActivity() {

    private lateinit var binding: ActivityOnlineQuizBinding
    private lateinit var testSetManager: TestSetManager

    private var testSetPath: String = ""
    private var testSetName: String = ""
    private var totalQuestions: Int = 10

    private var questions: List<TestSetManager.SavedQuestion> = emptyList()
    private var currentQuestionIndex = 0
    private var score = 0
    private var startTime: Long = 0L

    private var currentBitmap: Bitmap? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityOnlineQuizBinding.inflate(layoutInflater)
        setContentView(binding.root)

        testSetManager = TestSetManager(this)

        testSetPath = intent.getStringExtra("test_set_path") ?: ""
        testSetName = intent.getStringExtra("test_set_name") ?: ""
        totalQuestions = intent.getIntExtra("question_count", 10)

        if (testSetPath.isEmpty()) {
            Toast.makeText(this, "テストセットが見つかりません", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        loadAndStartTest()
    }

    private fun loadAndStartTest() {
        // テストセット情報を取得
        val testSetInfo = TestSetManager.TestSetInfo(
            name = testSetName,
            genre = OnlineQuizManager.Genre.ALL, // ここでは使わない
            questionCount = totalQuestions,
            createdAt = 0L,
            dirPath = testSetPath
        )

        // 問題を読み込み
        val allQuestions = testSetManager.loadTestSet(testSetInfo)
        
        if (allQuestions.isEmpty()) {
            Toast.makeText(this, "問題の読み込みに失敗しました", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        // シャッフルして必要数だけ取得
        questions = allQuestions.shuffled().take(totalQuestions)
        totalQuestions = questions.size

        // 読み込み画面を非表示にしてクイズ画面を表示
        binding.loadingContainer.visibility = View.GONE
        binding.ivQuizImage.visibility = View.VISIBLE
        binding.buttonContainer.visibility = View.VISIBLE
        binding.cancelContainer.visibility = View.GONE
        
        // ボタンを有効化
        binding.btnSame.isEnabled = true
        binding.btnDifferent.isEnabled = true

        // ボタン設定
        binding.btnSame.setOnClickListener { checkAnswer(true) }
        binding.btnDifferent.setOnClickListener { checkAnswer(false) }

        startTime = SystemClock.elapsedRealtime()
        showQuestion()
    }

    private fun showQuestion() {
        if (currentQuestionIndex >= questions.size) {
            finishQuiz()
            return
        }

        val question = questions[currentQuestionIndex]
        binding.tvProgress.text = "問題 ${currentQuestionIndex + 1} / $totalQuestions"
        binding.tvScore.text = "$score 点"
        binding.tvGenre.text = "📁 $testSetName"

        // 画像読み込み
        val testSetInfo = TestSetManager.TestSetInfo(
            name = testSetName,
            genre = OnlineQuizManager.Genre.ALL,
            questionCount = totalQuestions,
            createdAt = 0L,
            dirPath = testSetPath
        )

        // 前の画像をリサイクル
        currentBitmap?.recycle()
        currentBitmap = testSetManager.loadQuestionImage(testSetInfo, question)
        
        if (currentBitmap != null) {
            binding.ivQuizImage.setImageBitmap(currentBitmap)
        } else {
            // 画像読み込み失敗時はスキップ
            currentQuestionIndex++
            showQuestion()
        }

        // 経過時間更新
        updateTimer()
    }

    private fun updateTimer() {
        val elapsed = SystemClock.elapsedRealtime() - startTime
        val seconds = (elapsed / 1000).toInt()
        val minutes = seconds / 60
        val secs = seconds % 60
        binding.tvTimer.text = String.format("%d:%02d", minutes, secs)

        binding.root.postDelayed({
            if (!isFinishing) {
                updateTimer()
            }
        }, 1000)
    }

    private fun checkAnswer(userAnswerSame: Boolean) {
        val question = questions[currentQuestionIndex]
        val correct = (userAnswerSame == question.isSame)
        
        if (correct) {
            score++
        }

        currentQuestionIndex++
        showQuestion()
    }

    private fun finishQuiz() {
        val elapsedTime = SystemClock.elapsedRealtime() - startTime

        // 画像のクリア
        currentBitmap?.recycle()
        currentBitmap = null
        binding.ivQuizImage.setImageBitmap(null)

        // ベストスコア更新（テストセット用）
        val prefs = getSharedPreferences("quiz_prefs", MODE_PRIVATE)
        val bestScore = prefs.getInt("best_score_testset", 0)
        val bestTime = prefs.getLong("best_time_testset", Long.MAX_VALUE)

        if (score > bestScore || (score == bestScore && elapsedTime < bestTime)) {
            prefs.edit()
                .putInt("best_score_testset", score)
                .putLong("best_time_testset", elapsedTime)
                .apply()
        }

        // 結果画面へ
        val intent = android.content.Intent(this, ResultActivity::class.java)
        intent.putExtra("score", score)
        intent.putExtra("total", totalQuestions)
        intent.putExtra("time", elapsedTime)
        intent.putExtra("mode", "testset")
        startActivity(intent)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        currentBitmap?.recycle()
        currentBitmap = null
    }
}
