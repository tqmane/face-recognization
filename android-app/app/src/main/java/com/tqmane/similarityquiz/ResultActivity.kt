package com.tqmane.similarityquiz

import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
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
        
        // Serializable取得（互換性のある方法）
        val results: ArrayList<QuizResult> = try {
            @Suppress("DEPRECATION", "UNCHECKED_CAST")
            val rawList = intent.getSerializableExtra("results")
            when (rawList) {
                is ArrayList<*> -> ArrayList(rawList.filterIsInstance<QuizResult>())
                else -> arrayListOf()
            }
        } catch (e: Exception) {
            android.util.Log.e("ResultActivity", "Failed to get results", e)
            arrayListOf()
        }

        // デバッグログ
        android.util.Log.d("ResultActivity", "Received ${results.size} results for $totalQuestions questions")
        results.forEachIndexed { index, result ->
            android.util.Log.d("ResultActivity", "Result[$index]: Q${result.questionNumber}, correct=${result.isCorrect}")
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

        // 結果リスト（全問題表示）
        binding.rvResults.layoutManager = LinearLayoutManager(this)
        binding.rvResults.adapter = ImprovedResultAdapter(results)
        binding.rvResults.isNestedScrollingEnabled = false

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

/**
 * 改善された結果表示アダプター
 * 全問題の詳細情報を表示
 */
class ImprovedResultAdapter(private val results: List<QuizResult>) :
    RecyclerView.Adapter<ImprovedResultAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val card: CardView = view as CardView
        val viewResultBg: View = view.findViewById(R.id.viewResultBg)
        val ivResultIcon: ImageView = view.findViewById(R.id.ivResultIcon)
        val tvQuestionNumber: TextView = view.findViewById(R.id.tvQuestionNumber)
        val tvDescription: TextView = view.findViewById(R.id.tvDescription)
        val tvCorrectAnswer: TextView = view.findViewById(R.id.tvCorrectAnswer)
        val tvUserAnswer: TextView = view.findViewById(R.id.tvUserAnswer)
        val tvResponseTime: TextView = view.findViewById(R.id.tvResponseTime)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_result, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val result = results[position]
        val context = holder.itemView.context
        
        val greenColor = ContextCompat.getColor(context, R.color.ios_green)
        val redColor = ContextCompat.getColor(context, R.color.ios_red)
        val textPrimaryColor = ContextCompat.getColor(context, R.color.text_primary)
        val textSecondaryColor = ContextCompat.getColor(context, R.color.text_secondary)
        val textTertiaryColor = ContextCompat.getColor(context, R.color.text_tertiary)
        
        // 正解/不正解の背景色
        val bgDrawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (result.isCorrect) greenColor else redColor)
        }
        holder.viewResultBg.background = bgDrawable
        
        // アイコン設定
        if (result.isCorrect) {
            holder.ivResultIcon.setImageResource(android.R.drawable.checkbox_on_background)
        } else {
            holder.ivResultIcon.setImageResource(android.R.drawable.ic_delete)
        }
        holder.ivResultIcon.imageTintList = ColorStateList.valueOf(
            ContextCompat.getColor(context, android.R.color.white)
        )
        
        // カードの背景色
        val bgColor = if (result.isCorrect) {
            ContextCompat.getColor(context, R.color.result_correct_bg)
        } else {
            ContextCompat.getColor(context, R.color.result_incorrect_bg)
        }
        holder.card.setCardBackgroundColor(bgColor)
        
        // 問題番号（ダークモード対応）
        holder.tvQuestionNumber.text = "問題 ${result.questionNumber}"
        holder.tvQuestionNumber.setTextColor(textPrimaryColor)
        
        // 説明（imagePath に説明が入っている）
        holder.tvDescription.text = result.imagePath
        holder.tvDescription.setTextColor(textSecondaryColor)
        
        // 正解
        val correctAnswer = if (result.isSame) "同じ" else "違う"
        holder.tvCorrectAnswer.text = "正解: $correctAnswer"
        holder.tvCorrectAnswer.setTextColor(textTertiaryColor)
        
        // ユーザーの回答
        val userAnswer = if (result.userAnswer) "同じ" else "違う"
        holder.tvUserAnswer.text = "回答: $userAnswer"
        holder.tvUserAnswer.setTextColor(if (result.isCorrect) greenColor else redColor)
        
        // 回答時間
        val responseSeconds = result.responseTimeMs / 1000.0
        holder.tvResponseTime.text = String.format("%.1f秒", responseSeconds)
        holder.tvResponseTime.setTextColor(textTertiaryColor)
    }

    override fun getItemCount() = results.size
}
