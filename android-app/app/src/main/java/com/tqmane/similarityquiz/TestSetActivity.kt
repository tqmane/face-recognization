package com.tqmane.similarityquiz

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import androidx.lifecycle.lifecycleScope
import com.tqmane.similarityquiz.databinding.ActivityTestSetBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * テストセット管理画面
 * - 新規作成（200枚ダウンロード）
 * - 既存セットからテスト開始
 * - 削除
 */
class TestSetActivity : AppCompatActivity() {

    private lateinit var binding: ActivityTestSetBinding
    private lateinit var testSetManager: TestSetManager
    private lateinit var notificationHelper: DownloadNotificationHelper

    private var downloadJob: Job? = null
    private var isCancelled = false
    
    // 現在ダウンロード中のジャンル名
    private var currentGenreName: String = ""

    // 通知権限リクエスト
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            Toast.makeText(this, "通知が有効になりました", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityTestSetBinding.inflate(layoutInflater)
        setContentView(binding.root)

        testSetManager = TestSetManager(this)
        notificationHelper = DownloadNotificationHelper(this)

        // 通知権限を確認（Android 13以上）
        requestNotificationPermissionIfNeeded()

        binding.btnCreateNew.setOnClickListener {
            showGenreSelectionDialog()
        }

        binding.btnCancel.setOnClickListener {
            cancelDownload()
        }

        binding.btnBack.setOnClickListener {
            finish()
        }

        refreshTestSetList()
    }

    /**
     * 通知権限をリクエスト（Android 13以上）
     */
    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!notificationHelper.hasNotificationPermission()) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun refreshTestSetList() {
        val testSets = testSetManager.getAvailableTestSets()
        val storageUsed = testSetManager.getTotalStorageUsed()

        binding.tvStorageInfo.text = "使用容量: %.1f MB".format(storageUsed)

        if (testSets.isEmpty()) {
            binding.tvNoSets.visibility = View.VISIBLE
            binding.testSetList.visibility = View.GONE
        } else {
            binding.tvNoSets.visibility = View.GONE
            binding.testSetList.visibility = View.VISIBLE
            binding.testSetList.removeAllViews()

            for (testSet in testSets) {
                addTestSetCard(testSet)
            }
        }
    }

    private fun addTestSetCard(testSet: TestSetManager.TestSetInfo) {
        val cardView = layoutInflater.inflate(
            R.layout.item_test_set,
            binding.testSetList,
            false
        )

        val dateFormat = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.JAPAN)
        val dateStr = dateFormat.format(Date(testSet.createdAt))

        cardView.findViewById<android.widget.TextView>(R.id.tvSetName).text = testSet.genre.displayName
        cardView.findViewById<android.widget.TextView>(R.id.tvSetInfo).text = 
            "${testSet.questionCount}問 | $dateStr"

        // テスト開始ボタン
        cardView.findViewById<View>(R.id.btnStartTest).setOnClickListener {
            showQuestionCountDialog(testSet)
        }

        // 編集ボタン
        cardView.findViewById<View>(R.id.btnEdit).setOnClickListener {
            openFoulEdit(testSet)
        }

        // 削除ボタン
        cardView.findViewById<View>(R.id.btnDelete).setOnClickListener {
            confirmDelete(testSet)
        }

        binding.testSetList.addView(cardView)
    }

    private fun showGenreSelectionDialog() {
        val genres = OnlineQuizManager.Genre.values()
        
        MaterialAlertDialogBuilder(this)
            .setTitle("ダウンロードするジャンル")
            .setItems(genres.map { it.displayName }.toTypedArray()) { _, which ->
                showQuestionCountSelectionDialog(genres[which])
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun showQuestionCountSelectionDialog(genre: OnlineQuizManager.Genre) {
        val options = arrayOf("50問", "100問", "200問", "300問")
        val counts = intArrayOf(50, 100, 200, 300)

        MaterialAlertDialogBuilder(this)
            .setTitle("ダウンロードする問題数")
            .setItems(options) { _, which ->
                startDownload(genre, counts[which])
            }
            .setNegativeButton("戻る") { _, _ ->
                showGenreSelectionDialog()
            }
            .show()
    }

    private fun startDownload(genre: OnlineQuizManager.Genre, totalQuestions: Int) {
        isCancelled = false
        currentGenreName = genre.displayName
        
        // UI更新
        binding.downloadingPanel.visibility = View.VISIBLE
        binding.normalPanel.visibility = View.GONE
        binding.tvDownloadStatus.text = "準備中..."
        binding.tvDownloadProgress.text = "0 / $totalQuestions"
        binding.progressBar.progress = 0
        binding.tvProgressPercent.text = "0%"

        // 通知を表示
        notificationHelper.showDownloadStarted(genre.displayName, totalQuestions)

        downloadJob = lifecycleScope.launch {
            val successCount = testSetManager.createTestSet(
                genre = genre,
                totalQuestions = totalQuestions,
                onProgress = { current, total ->
                    if (!isCancelled) {
                        runOnUiThread {
                            val progress = (current * 100) / total
                            binding.tvDownloadStatus.text = "ダウンロード中..."
                            binding.tvDownloadProgress.text = "$current / $total"
                            binding.progressBar.progress = progress
                            binding.tvProgressPercent.text = "$progress%"
                        }
                        // 通知も更新
                        notificationHelper.updateProgress(genre.displayName, current, total)
                    }
                }
            )

            runOnUiThread {
                binding.downloadingPanel.visibility = View.GONE
                binding.normalPanel.visibility = View.VISIBLE

                if (isCancelled) {
                    notificationHelper.showDownloadCancelled()
                    Toast.makeText(this@TestSetActivity, "キャンセルしました", Toast.LENGTH_SHORT).show()
                } else if (successCount > 0) {
                    notificationHelper.showDownloadComplete(genre.displayName, successCount)
                    Toast.makeText(
                        this@TestSetActivity,
                        "${genre.displayName}の${successCount}問を保存しました",
                        Toast.LENGTH_LONG
                    ).show()
                    refreshTestSetList()
                } else {
                    notificationHelper.showDownloadFailed(genre.displayName)
                    Toast.makeText(
                        this@TestSetActivity,
                        "ダウンロードに失敗しました",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }

    private fun cancelDownload() {
        isCancelled = true
        downloadJob?.cancel()
        notificationHelper.showDownloadCancelled()
        binding.downloadingPanel.visibility = View.GONE
        binding.normalPanel.visibility = View.VISIBLE
    }

    private fun showQuestionCountDialog(testSet: TestSetManager.TestSetInfo) {
        val maxQuestions = testSet.questionCount
        val options = mutableListOf<String>()
        val counts = mutableListOf<Int>()

        if (maxQuestions >= 5) { options.add("5問（お試し）"); counts.add(5) }
        if (maxQuestions >= 10) { options.add("10問"); counts.add(10) }
        if (maxQuestions >= 20) { options.add("20問"); counts.add(20) }
        if (maxQuestions >= 50) { options.add("50問"); counts.add(50) }
        if (maxQuestions >= 100) { options.add("100問"); counts.add(100) }
        options.add("全問（${maxQuestions}問）"); counts.add(maxQuestions)

        MaterialAlertDialogBuilder(this)
            .setTitle("問題数を選択")
            .setItems(options.toTypedArray()) { _, which ->
                startTestFromSet(testSet, counts[which])
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun startTestFromSet(testSet: TestSetManager.TestSetInfo, questionCount: Int) {
        val intent = Intent(this, OnlineQuizActivity::class.java)
        intent.putExtra("test_set_path", testSet.dirPath)
        intent.putExtra("test_set_name", testSet.genre.displayName)
        intent.putExtra("question_count", questionCount)
        intent.putExtra("genre", testSet.genre.name)
        startActivity(intent)
    }

    private fun openFoulEdit(testSet: TestSetManager.TestSetInfo) {
        val intent = Intent(this, FoulEditActivity::class.java)
        intent.putExtra("test_set_path", testSet.dirPath)
        intent.putExtra("test_set_name", testSet.genre.displayName)
        intent.putExtra("genre", testSet.genre.name)
        startActivity(intent)
    }

    override fun onResume() {
        super.onResume()
        // 編集画面から戻ってきたときにリストを更新
        refreshTestSetList()
    }

    private fun confirmDelete(testSet: TestSetManager.TestSetInfo) {
        MaterialAlertDialogBuilder(this)
            .setTitle("削除確認")
            .setMessage("「${testSet.genre.displayName}」(${testSet.questionCount}問)を削除しますか？")
            .setPositiveButton("削除") { _, _ ->
                if (testSetManager.deleteTestSet(testSet)) {
                    Toast.makeText(this, "削除しました", Toast.LENGTH_SHORT).show()
                    refreshTestSetList()
                } else {
                    Toast.makeText(this, "削除に失敗しました", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    override fun onDestroy() {
        super.onDestroy()
        downloadJob?.cancel()
    }
}
