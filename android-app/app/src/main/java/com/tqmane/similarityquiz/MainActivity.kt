package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.tqmane.similarityquiz.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // オフラインモード（端末内の画像）
        binding.btnStart.setOnClickListener {
            startActivity(Intent(this, QuizActivity::class.java))
        }

        // オンラインモード（問題数選択ダイアログ表示）
        binding.btnOnline.setOnClickListener {
            showQuestionCountDialog()
        }

        // テストセット管理
        binding.btnTestSet.setOnClickListener {
            startActivity(Intent(this, TestSetActivity::class.java))
        }

        updateBestScores()
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
        updateBestScores()
    }

    private fun updateBestScores() {
        val prefs = getSharedPreferences("quiz_prefs", MODE_PRIVATE)
        
        // オフラインモードのベストスコア
        val bestScore = prefs.getInt("best_score", 0)
        val bestTime = prefs.getLong("best_time", 0L)
        
        // オンラインモードのベストスコア
        val bestScoreOnline = prefs.getInt("best_score_online", 0)
        val bestTimeOnline = prefs.getLong("best_time_online", 0L)

        val sb = StringBuilder()
        
        if (bestScore > 0) {
            sb.append("オフライン: $bestScore 点 (${formatTime(bestTime)})")
        }
        
        if (bestScoreOnline > 0) {
            if (sb.isNotEmpty()) sb.append("\n")
            sb.append("オンライン: $bestScoreOnline 点 (${formatTime(bestTimeOnline)})")
        }
        
        if (sb.isEmpty()) {
            binding.tvBestScore.text = "まだ記録がありません"
        } else {
            binding.tvBestScore.text = sb.toString()
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
