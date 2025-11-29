package com.tqmane.similarityquiz

import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.tqmane.similarityquiz.databinding.ActivityResultBinding

class ResultActivity : AppCompatActivity() {

    private lateinit var binding: ActivityResultBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityResultBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val score = intent.getIntExtra("score", 0)
        val totalQuestions = intent.getIntExtra("total_questions", 0)
        val totalTime = intent.getLongExtra("total_time", 0L)
        val responderName = intent.getStringExtra("responder_name") ?: ""
        
        // Android 13以降対応のSerializable取得
        val results: ArrayList<QuizResult> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getSerializableExtra("results", ArrayList::class.java)?.let { list ->
                ArrayList(list.filterIsInstance<QuizResult>())
            } ?: arrayListOf()
        } else {
            @Suppress("DEPRECATION")
            (intent.getSerializableExtra("results") as? ArrayList<*>)?.let { list ->
                ArrayList(list.filterIsInstance<QuizResult>())
            } ?: arrayListOf()
        }

        // スコア表示
        binding.tvFinalScore.text = "$score"
        
        // 正解率
        val correctCount = results.count { it.isCorrect }
        val accuracy = if (totalQuestions > 0) (correctCount * 100) / totalQuestions else 0
        binding.tvAccuracy.text = "$accuracy% ($correctCount/$totalQuestions)"

        // 合計時間
        binding.tvTotalTime.text = formatTime(totalTime)

        // 平均回答時間
        val avgTime = if (results.isNotEmpty()) results.map { it.responseTimeMs }.average().toLong() else 0L
        binding.tvAverageTime.text = formatTime(avgTime)

        // ベストスコアかどうか
        val prefs = getSharedPreferences("quiz_prefs", MODE_PRIVATE)
        val bestScore = prefs.getInt("best_score_online", 0)
        if (score >= bestScore && score > 0) {
            binding.tvNewRecord.visibility = View.VISIBLE
            binding.tvNewRecord.text = "🎉 新記録！"
        } else {
            binding.tvNewRecord.visibility = View.GONE
        }

        // 結果リスト
        binding.rvResults.layoutManager = LinearLayoutManager(this)
        binding.rvResults.adapter = ResultAdapter(results)

        // 戻るボタン
        binding.btnBackToHome.setOnClickListener {
            finish()
        }

        // もう一度ボタン（オンラインモードのみ）
        binding.btnRetry.setOnClickListener {
            startActivity(android.content.Intent(this, OnlineQuizActivity::class.java))
            finish()
        }
    }

    private fun formatTime(millis: Long): String {
        val seconds = millis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        return if (minutes > 0) {
            "${minutes}分${secs}秒"
        } else {
            "${secs}.${(millis % 1000) / 100}秒"
        }
    }
}

class ResultAdapter(private val results: List<QuizResult>) :
    RecyclerView.Adapter<ResultAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvQuestion: TextView = view.findViewById(android.R.id.text1)
        val tvDetail: TextView = view.findViewById(android.R.id.text2)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(android.R.layout.simple_list_item_2, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val result = results[position]
        val mark = if (result.isCorrect) "⭕" else "❌"
        val answer = if (result.isSame) "同じ" else "違う"
        val userAns = if (result.userAnswer) "同じ" else "違う"
        
        holder.tvQuestion.text = "$mark 問題${result.questionNumber}"
        holder.tvDetail.text = "正解: $answer / あなた: $userAns (${result.responseTimeMs / 1000}.${(result.responseTimeMs % 1000) / 100}秒)"
    }

    override fun getItemCount() = results.size
}
