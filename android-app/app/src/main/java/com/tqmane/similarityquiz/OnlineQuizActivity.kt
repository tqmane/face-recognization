package com.tqmane.similarityquiz

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.view.LayoutInflater
import android.view.View
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
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
    
    // フォアグラウンドサービス
    private var downloadService: DownloadService? = null
    private var serviceBound = false
    
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as DownloadService.LocalBinder
            downloadService = binder.getService()
            serviceBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            downloadService = null
            serviceBound = false
        }
    }
    
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
    
    // テストセットモード用
    private var testSetPath: String? = null
    
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
        
        // 問題数を取得（両方のキーに対応）
        totalQuestions = intent.getIntExtra("question_count", 
            intent.getIntExtra("total_questions", 10))
        
        // ジャンルを取得
        val genreName = intent.getStringExtra("genre")
        selectedGenre = try {
            OnlineQuizManager.Genre.valueOf(genreName ?: "ALL")
        } catch (e: Exception) {
            OnlineQuizManager.Genre.ALL
        }
        
        // テストセットパスを取得（あればテストセットモード）
        testSetPath = intent.getStringExtra("test_set_path")
        
        setupButtons()
        showLoadingUI()
        
        if (testSetPath != null) {
            prepareQuestionsFromTestSet()
        } else {
            prepareAllQuestions()
        }
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
        
        binding.btnQuit.setOnClickListener {
            showQuitConfirmDialog()
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
        
        // クイズボタンを表示、キャンセルボタンを非表示、中断ボタンを表示
        binding.buttonContainer.visibility = View.VISIBLE
        binding.cancelContainer.visibility = View.GONE
        binding.btnQuit.visibility = View.VISIBLE
    }

    /**
     * キャンセル確認ダイアログ
     */
    private fun showCancelConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("キャンセルしますか？")
            .setMessage("ダウンロード中の画像はすべて破棄されます。\n本当にキャンセルしますか？")
            .setPositiveButton("キャンセルする") { _, _ ->
                cancelDownload()
            }
            .setNegativeButton("続ける", null)
            .show()
    }

    /**
     * クイズ中断確認ダイアログ
     */
    private fun showQuitConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("テストを中断しますか？")
            .setMessage("中断すると、途中までのテストデータは保存されず、\nすべて破棄されます。\n\n本当に中断しますか？")
            .setPositiveButton("中断する") { _, _ ->
                quitQuiz()
            }
            .setNegativeButton("続ける", null)
            .show()
    }

    /**
     * クイズを中断して終了
     */
    private fun quitQuiz() {
        timer?.cancel()
        cleanupImages()
        Toast.makeText(this, "テストを中断しました", Toast.LENGTH_SHORT).show()
        finish()
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
        
        // サービスを停止
        stopDownloadService()
        
        Toast.makeText(this, "キャンセルしました", Toast.LENGTH_SHORT).show()
        finish()
    }

    /**
     * フォアグラウンドサービスを開始
     */
    private fun startDownloadService() {
        val intent = Intent(this, DownloadService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }
    
    /**
     * フォアグラウンドサービスを停止
     */
    private fun stopDownloadService() {
        if (serviceBound) {
            downloadService?.complete()
            unbindService(serviceConnection)
            serviceBound = false
        }
    }

    /**
     * 全問題の画像を事前にダウンロード（並列高速版）
     */
    private fun prepareAllQuestions() {
        // 新しいテスト開始時に使用済みURLをクリア
        quizManager.reliableSource.clearUsedUrls()
        quizManager.scraper.clearUsedUrls()
        
        // フォアグラウンドサービスを開始（省電力モードでも殺されにくくする）
        startDownloadService()
        
        downloadJob = lifecycleScope.launch {
            preparedQuestions.clear()
            
            val downloadStartTime = System.currentTimeMillis()
            android.util.Log.d("OnlineQuiz", "Download started at $downloadStartTime")
            
            // 問題設定を事前に生成（余裕を持って3倍用意）
            val questionConfigs = (0 until totalQuestions * 3).map {
                quizManager.generateRandomQuestion(selectedGenre)
            }
            
            var successCount = 0
            var configIndex = 0
            
            // 順番に処理（並列で2問ずつダウンロード - メモリ節約）
            while (successCount < totalQuestions && configIndex < questionConfigs.size && !isCancelled) {
                val batchStartTime = System.currentTimeMillis()
                
                // 進捗を更新
                val progress = (successCount * 100) / totalQuestions
                runOnUiThread {
                    if (!isCancelled) {
                        binding.tvLoadingText.text = "画像を準備中..."
                        binding.tvLoadingSubtext.text = "$successCount / $totalQuestions 問を取得しました"
                        binding.progressBar.progress = progress
                        binding.tvProgressPercent.text = "$progress%"
                        
                        // 通知も更新
                        downloadService?.updateProgress(successCount, totalQuestions)
                    }
                }

                // 次の2つのconfigを取得（メモリ節約のため並列数を削減）
                val batchSize = minOf(2, questionConfigs.size - configIndex)
                val batch = questionConfigs.subList(configIndex, configIndex + batchSize)
                configIndex += batchSize

                // 並列ダウンロード（Dispatchers.IOで実行）
                // 信頼性の高いソース（iNaturalist, Dog API等）を優先使用
                val results = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    batch.map { config ->
                        async {
                            try {
                                // まず信頼性の高いソースを試す
                                var bitmap = if (config.isSame) {
                                    quizManager.reliableSource.createSameImage(config.itemId1)
                                } else {
                                    quizManager.reliableSource.createComparisonImage(config.itemId1, config.itemId2)
                                }
                                
                                // 信頼ソースで取得できない場合、Bingフォールバック
                                if (bitmap == null) {
                                    android.util.Log.d("OnlineQuiz", "Falling back to Bing for ${config.description}")
                                    bitmap = if (config.isSame) {
                                        quizManager.scraper.createSameImage(config.query1)
                                    } else {
                                        quizManager.scraper.createComparisonImage(config.query1, config.query2)
                                    }
                                }
                                
                                if (bitmap != null) {
                                    PreparedQuestion(bitmap, config.isSame, config.description)
                                } else null
                            } catch (e: Exception) {
                                android.util.Log.e("OnlineQuiz", "Download error: ${e.message}")
                                null
                            }
                        }
                    }.awaitAll().filterNotNull()
                }
                
                val batchTime = System.currentTimeMillis() - batchStartTime
                android.util.Log.d("OnlineQuiz", "Batch completed: ${results.size} images in ${batchTime}ms")
                
                // 成功した分だけ追加
                for (result in results) {
                    if (successCount >= totalQuestions || isCancelled) break
                    preparedQuestions.add(result)
                    successCount++
                }
            }

            runOnUiThread {
                if (isCancelled) return@runOnUiThread
                
                val totalDownloadTime = System.currentTimeMillis() - downloadStartTime
                android.util.Log.d("OnlineQuiz", "Download completed: ${preparedQuestions.size} questions in ${totalDownloadTime}ms")
                
                // ダウンロード完了、サービスを停止
                stopDownloadService()
                
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
     * テストセットから画像を読み込む
     */
    private fun prepareQuestionsFromTestSet() {
        val path = testSetPath ?: return
        val testSetManager = TestSetManager(this)
        
        downloadJob = lifecycleScope.launch {
            preparedQuestions.clear()
            
            runOnUiThread {
                binding.tvLoadingText.text = "テストセットから読み込み中..."
                binding.tvLoadingSubtext.text = "保存された画像を準備しています"
            }
            
            val questions = testSetManager.loadQuestionsFromTestSet(path, totalQuestions)
            
            for ((index, question) in questions.withIndex()) {
                if (isCancelled) break
                preparedQuestions.add(PreparedQuestion(
                    bitmap = question.bitmap,
                    isSame = question.isSame,
                    description = question.description
                ))
                
                val progress = ((index + 1) * 100) / questions.size
                runOnUiThread {
                    binding.progressBar.progress = progress
                    binding.tvProgressPercent.text = "$progress%"
                    binding.tvLoadingSubtext.text = "${index + 1} / ${questions.size} 問を読み込みました"
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
                        "テストセットの読み込みに失敗しました。",
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
        val recentNames = historyManager.getRecentResponderNames()
        
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_name_input, null)
        val editText = dialogView.findViewById<EditText>(R.id.editName)
        val chipGroup = dialogView.findViewById<com.google.android.material.chip.ChipGroup>(R.id.chipGroupNames)
        val tvRecentLabel = dialogView.findViewById<TextView>(R.id.tvRecentLabel)
        
        // 直近の名前をChipとして追加
        if (recentNames.isNotEmpty()) {
            tvRecentLabel.visibility = View.VISIBLE
            chipGroup.visibility = View.VISIBLE
            recentNames.forEach { name ->
                val chip = com.google.android.material.chip.Chip(this).apply {
                    text = name
                    isCheckable = true
                    setOnClickListener {
                        editText.setText(name)
                        editText.setSelection(name.length)
                    }
                    setOnLongClickListener {
                        showDeleteResponderNameDialog(name) {
                            chipGroup.removeView(this)
                            if (chipGroup.childCount == 0) {
                                tvRecentLabel.visibility = View.GONE
                                chipGroup.visibility = View.GONE
                            }
                        }
                        true
                    }
                }
                chipGroup.addView(chip)
            }
        } else {
            tvRecentLabel.visibility = View.GONE
            chipGroup.visibility = View.GONE
        }
        
        MaterialAlertDialogBuilder(this)
            .setTitle("回答者の名前")
            .setMessage("任意入力（スキップ可）")
            .setView(dialogView)
            .setPositiveButton("開始") { _, _ ->
                responderName = editText.text.toString().trim()
                startCountdown()
            }
            .setNeutralButton("スキップ") { _, _ ->
                responderName = ""
                startCountdown()
            }
            .setNegativeButton("キャンセル") { _, _ ->
                // 画像をクリアして終了
                cleanupImages()
                finish()
            }
            .setCancelable(false)
            .show()
    }
    
    private fun showDeleteResponderNameDialog(name: String, onDeleted: () -> Unit) {
        MaterialAlertDialogBuilder(this)
            .setTitle("履歴から削除")
            .setMessage("「$name」を履歴から削除しますか？")
            .setPositiveButton("削除") { _, _ ->
                historyManager.removeResponderName(name)
                onDeleted()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    /**
     * カウントダウン開始
     */
    private fun startCountdown() {
        // カウントダウンUIを表示
        binding.loadingContainer.visibility = View.VISIBLE
        binding.ivQuizImage.visibility = View.INVISIBLE
        binding.buttonContainer.visibility = View.GONE
        binding.cancelContainer.visibility = View.GONE
        binding.btnQuit.visibility = View.GONE
        
        // カウントダウンテキストを表示
        binding.progressLoading.visibility = View.GONE
        binding.progressBar.visibility = View.GONE
        binding.tvProgressPercent.visibility = View.GONE
        binding.tvLoadingSubtext.visibility = View.GONE
        binding.tvLoadingText.textSize = 80f
        
        var countdown = 3
        val countdownHandler = android.os.Handler(mainLooper)
        
        val countdownRunnable = object : Runnable {
            override fun run() {
                if (countdown > 0) {
                    binding.tvLoadingText.text = countdown.toString()
                    countdown--
                    countdownHandler.postDelayed(this, 1000)
                } else {
                    binding.tvLoadingText.text = "START!"
                    binding.tvLoadingText.textSize = 48f
                    countdownHandler.postDelayed({
                        startQuiz()
                    }, 500)
                }
            }
        }
        
        countdownHandler.post(countdownRunnable)
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
        
        // ローディングテキストを元に戻す
        binding.tvLoadingText.textSize = 18f
        binding.progressLoading.visibility = View.VISIBLE
        binding.progressBar.visibility = View.VISIBLE
        binding.tvProgressPercent.visibility = View.VISIBLE
        binding.tvLoadingSubtext.visibility = View.VISIBLE
        
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
        
        // Firebaseにもアップロード（サインイン済みの場合）
        val syncManager = FirebaseSyncManager.getInstance(this)
        if (syncManager.isSignedIn) {
            lifecycleScope.launch {
                syncManager.uploadHistory(history)
            }
        }

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
        } else if (currentQuestionIndex > 0 && currentQuestionIndex < preparedQuestions.size) {
            // クイズ中の場合は中断確認ダイアログ
            showQuitConfirmDialog()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
        downloadJob?.cancel()
        
        // サービスのクリーンアップ
        if (serviceBound) {
            try {
                unbindService(serviceConnection)
            } catch (e: Exception) {
                // 無視
            }
            serviceBound = false
        }
        
        cleanupImages()
    }
}
