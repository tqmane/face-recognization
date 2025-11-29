package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.tqmane.similarityquiz.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var historyManager: HistoryManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        historyManager = HistoryManager.getInstance(this)

        // オンラインモード（問題数選択ダイアログ表示）
        binding.btnOnline.setOnClickListener {
            showQuestionCountDialog()
        }

        // テストセット管理
        binding.btnTestSet.setOnClickListener {
            startActivity(Intent(this, TestSetActivity::class.java))
        }
        
        // 履歴画面
        binding.cardHistory?.setOnClickListener {
            startActivity(Intent(this, HistoryActivity::class.java))
        }

        updateStats()
    }

    private var selectedGenre: OnlineQuizManager.Genre = OnlineQuizManager.Genre.ALL

    private fun showQuestionCountDialog() {
        // まずジャンルを選択
        showGenreDialog()
    }

    private fun showGenreDialog() {
        val genres = OnlineQuizManager.Genre.values()
        val options = genres.map { "${it.displayName}\n${it.description}" }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("ジャンルを選択")
            .setItems(genres.map { it.displayName }.toTypedArray()) { _, which ->
                selectedGenre = genres[which]
                showCountDialog()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun showCountDialog() {
        val options = arrayOf("5問（お試し）", "10問", "15問", "20問")
        val counts = intArrayOf(5, 10, 15, 20)

        AlertDialog.Builder(this)
            .setTitle("問題数を選択")
            .setItems(options) { _, which ->
                val intent = Intent(this, OnlineQuizActivity::class.java)
                intent.putExtra("total_questions", counts[which])
                intent.putExtra("genre", selectedGenre.name)
                startActivity(intent)
            }
            .setNegativeButton("戻る") { _, _ ->
                showGenreDialog()
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

    private fun formatTime(millis: Long): String {
        val seconds = millis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        return if (minutes > 0) {
            "${minutes}分${secs}秒"
        } else {
            "${secs}秒"
        }
    }
}
