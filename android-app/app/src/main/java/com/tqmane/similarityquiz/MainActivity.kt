package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var historyManager: HistoryManager
    private lateinit var zipService: ZipTestSetService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // AppSettingsを初期化
        AppSettings.init(this)
        
        historyManager = HistoryManager.getInstance(this)
        zipService = ZipTestSetService(this)

        // テスト開始（ダウンロード済みテストセットから選択）
        binding.btnOnline.setOnClickListener {
            showTestSetSelection()
        }

        // テストセット管理
        binding.btnTestSet.setOnClickListener {
            startActivity(Intent(this, TestSetDownloadActivity::class.java))
        }
        
        // 履歴画面
        binding.cardHistory?.setOnClickListener {
            startActivity(Intent(this, HistoryActivity::class.java))
        }
        
        // 設定画面
        binding.btnSettings.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }

        updateStats()
    }

    private fun showTestSetSelection() {
        val downloaded = zipService.getDownloadedTestSets()
        
        if (downloaded.isEmpty()) {
            MaterialAlertDialogBuilder(this)
                .setTitle("テストセットがありません")
                .setMessage("まずテストセットをダウンロードしてください。")
                .setPositiveButton("ダウンロード") { _, _ ->
                    startActivity(Intent(this, TestSetDownloadActivity::class.java))
                }
                .setNegativeButton("キャンセル", null)
                .show()
            return
        }
        
        val names = downloaded.map { "${it.displayName} (${it.imageCount}枚)" }.toTypedArray()
        
        MaterialAlertDialogBuilder(this)
            .setTitle("テストセットを選択")
            .setItems(names) { _, which ->
                val testSet = downloaded[which]
                showQuestionCountDialog(testSet)
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun showQuestionCountDialog(testSet: ZipTestSetService.DownloadedTestSet) {
        val options = arrayOf("5問（お試し）", "10問", "15問", "20問")
        val counts = intArrayOf(5, 10, 15, 20)
        
        MaterialAlertDialogBuilder(this)
            .setTitle("${testSet.displayName} - 問題数")
            .setItems(options) { _, which ->
                val intent = Intent(this, ZipQuizActivity::class.java).apply {
                    putExtra("test_set_id", testSet.id)
                    putExtra("test_set_name", testSet.displayName)
                    putExtra("question_count", counts[which])
                }
                startActivity(intent)
            }
            .setNegativeButton("戻る") { _, _ ->
                showTestSetSelection()
            }
            .show()
    }

    override fun onResume() {
        super.onResume()
        updateStats()
    }

    private fun updateStats() {
        val stats = historyManager.getOverallStats()
        
        if (stats.totalTests > 0) {
            val sb = StringBuilder()
            sb.append("平均正答率: ${String.format("%.1f", stats.averageAccuracy)}%\n")
            sb.append("テスト回数: ${stats.totalTests}回")
            binding.tvBestScore.text = sb.toString()
        } else {
            binding.tvBestScore.text = "まだ記録がありません"
        }
    }
}
