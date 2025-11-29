package com.example.similarityquiz

import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.example.similarityquiz.databinding.ActivityTestSetBinding
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

    private var downloadJob: Job? = null
    private var isCancelled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityTestSetBinding.inflate(layoutInflater)
        setContentView(binding.root)

        testSetManager = TestSetManager(this)

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

        // 削除ボタン
        cardView.findViewById<View>(R.id.btnDelete).setOnClickListener {
            confirmDelete(testSet)
        }

        binding.testSetList.addView(cardView)
    }

    private fun showGenreSelectionDialog() {
        val genres = OnlineQuizManager.Genre.values()
        
        AlertDialog.Builder(this)
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

        AlertDialog.Builder(this)
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
        
        // UI更新
        binding.downloadingPanel.visibility = View.VISIBLE
        binding.normalPanel.visibility = View.GONE
        binding.tvDownloadStatus.text = "準備中..."
        binding.tvDownloadProgress.text = "0 / $totalQuestions"
        binding.progressBar.progress = 0
        binding.tvProgressPercent.text = "0%"

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
                    }
                }
            )

            runOnUiThread {
                binding.downloadingPanel.visibility = View.GONE
                binding.normalPanel.visibility = View.VISIBLE

                if (isCancelled) {
                    Toast.makeText(this@TestSetActivity, "キャンセルしました", Toast.LENGTH_SHORT).show()
                } else if (successCount > 0) {
                    Toast.makeText(
                        this@TestSetActivity,
                        "${genre.displayName}の${successCount}問を保存しました",
                        Toast.LENGTH_LONG
                    ).show()
                    refreshTestSetList()
                } else {
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

        AlertDialog.Builder(this)
            .setTitle("問題数を選択")
            .setItems(options.toTypedArray()) { _, which ->
                startTestFromSet(testSet, counts[which])
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun startTestFromSet(testSet: TestSetManager.TestSetInfo, questionCount: Int) {
        val intent = Intent(this, OfflineTestActivity::class.java)
        intent.putExtra("test_set_path", testSet.dirPath)
        intent.putExtra("test_set_name", testSet.genre.displayName)
        intent.putExtra("question_count", questionCount)
        startActivity(intent)
    }

    private fun confirmDelete(testSet: TestSetManager.TestSetInfo) {
        AlertDialog.Builder(this)
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
