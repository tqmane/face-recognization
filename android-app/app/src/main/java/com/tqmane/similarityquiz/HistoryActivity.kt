package com.tqmane.similarityquiz

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.tabs.TabLayout
import com.tqmane.similarityquiz.databinding.ActivityHistoryBinding
import java.text.SimpleDateFormat
import java.util.*

class HistoryActivity : AppCompatActivity() {

    private lateinit var binding: ActivityHistoryBinding
    private lateinit var historyManager: HistoryManager
    
    // 選択モード関連
    private var isSelectionMode = false
    private val selectedIds = mutableSetOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHistoryBinding.inflate(layoutInflater)
        setContentView(binding.root)

        historyManager = HistoryManager.getInstance(this)

        setSupportActionBar(binding.toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "テスト結果一覧"

        binding.toolbar.setNavigationOnClickListener { 
            if (isSelectionMode) {
                exitSelectionMode()
            } else {
                finish()
            }
        }

        // タブ設定
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("履歴"))
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("ジャンル別"))
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("全体統計"))
        binding.tabLayout.addTab(binding.tabLayout.newTab().setText("回答者別"))

        binding.tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                exitSelectionMode()
                updateContent(tab?.position ?: 0)
            }
            override fun onTabUnselected(tab: TabLayout.Tab?) {}
            override fun onTabReselected(tab: TabLayout.Tab?) {}
        })

        // 選択削除ボタン
        binding.btnSelectDelete.setOnClickListener {
            if (isSelectionMode) {
                // 選択中のものを削除
                if (selectedIds.isNotEmpty()) {
                    showDeleteSelectedDialog()
                }
            } else {
                // 選択モードに入る
                enterSelectionMode()
            }
        }

        // 全削除ボタン
        binding.btnClear.setOnClickListener {
            MaterialAlertDialogBuilder(this)
                .setTitle("全履歴を削除")
                .setMessage("全ての履歴を削除しますか？\nこの操作は取り消せません。")
                .setPositiveButton("削除") { _, _ ->
                    historyManager.clearHistories()
                    exitSelectionMode()
                    updateContent(binding.tabLayout.selectedTabPosition)
                }
                .setNegativeButton("キャンセル", null)
                .show()
        }

        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        updateContent(0)
    }
    
    private fun enterSelectionMode() {
        isSelectionMode = true
        selectedIds.clear()
        supportActionBar?.title = "0件選択中"
        binding.btnSelectDelete.text = "選択項目を削除"
        binding.btnSelectDelete.setIconResource(android.R.drawable.ic_menu_delete)
        updateContent(0) // 履歴タブを再描画
    }
    
    private fun exitSelectionMode() {
        isSelectionMode = false
        selectedIds.clear()
        supportActionBar?.title = "テスト結果一覧"
        binding.btnSelectDelete.text = "選択削除"
        binding.btnSelectDelete.setIconResource(android.R.drawable.ic_menu_agenda)
        if (binding.tabLayout.selectedTabPosition == 0) {
            updateContent(0)
        }
    }
    
    private fun updateSelectionCount() {
        supportActionBar?.title = "${selectedIds.size}件選択中"
    }
    
    private fun showDeleteSelectedDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("選択した履歴を削除")
            .setMessage("${selectedIds.size}件の履歴を削除しますか？\nこの操作は取り消せません。")
            .setPositiveButton("削除") { _, _ ->
                historyManager.deleteHistories(selectedIds)
                exitSelectionMode()
                updateContent(0)
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun showDeleteSingleDialog(history: QuizHistoryData) {
        MaterialAlertDialogBuilder(this)
            .setTitle("履歴を削除")
            .setMessage("「${history.genre}」の履歴を削除しますか？\nこの操作は取り消せません。")
            .setPositiveButton("削除") { _, _ ->
                historyManager.deleteHistory(history.id)
                updateContent(0)
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun updateContent(tabIndex: Int) {
        // 選択モードは履歴タブでのみ有効
        binding.btnSelectDelete.visibility = if (tabIndex == 0) View.VISIBLE else View.GONE
        
        when (tabIndex) {
            0 -> showHistoryList()
            1 -> showGenreStats()
            2 -> showOverallStats()
            3 -> showResponderStats()
        }
    }

    private fun showHistoryList() {
        val histories = historyManager.getHistories()
        if (histories.isEmpty()) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.recyclerView.visibility = View.GONE
            binding.statsContainer.visibility = View.GONE
        } else {
            binding.tvEmpty.visibility = View.GONE
            binding.recyclerView.visibility = View.VISIBLE
            binding.statsContainer.visibility = View.GONE
            binding.recyclerView.adapter = HistoryAdapter(
                histories = histories,
                isSelectionMode = isSelectionMode,
                selectedIds = selectedIds,
                onClick = { history ->
                    if (isSelectionMode) {
                        toggleSelection(history.id)
                    } else {
                        showHistoryDetail(history)
                    }
                },
                onLongClick = { history ->
                    if (!isSelectionMode) {
                        showDeleteSingleDialog(history)
                    }
                },
                onSelectionChanged = { id, isSelected ->
                    if (isSelected) {
                        selectedIds.add(id)
                    } else {
                        selectedIds.remove(id)
                    }
                    updateSelectionCount()
                }
            )
        }
    }
    
    private fun toggleSelection(id: String) {
        if (selectedIds.contains(id)) {
            selectedIds.remove(id)
        } else {
            selectedIds.add(id)
        }
        updateSelectionCount()
        (binding.recyclerView.adapter as? HistoryAdapter)?.notifyDataSetChanged()
    }

    private fun showGenreStats() {
        val stats = historyManager.getStatsByGenre()
        if (stats.isEmpty()) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.recyclerView.visibility = View.GONE
            binding.statsContainer.visibility = View.GONE
        } else {
            binding.tvEmpty.visibility = View.GONE
            binding.recyclerView.visibility = View.VISIBLE
            binding.statsContainer.visibility = View.GONE
            binding.recyclerView.adapter = StatsAdapter(stats.values.toList())
        }
    }

    private fun showOverallStats() {
        val stats = historyManager.getOverallStats()
        if (stats.totalTests == 0) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.recyclerView.visibility = View.GONE
            binding.statsContainer.visibility = View.GONE
        } else {
            binding.tvEmpty.visibility = View.GONE
            binding.recyclerView.visibility = View.GONE
            binding.statsContainer.visibility = View.VISIBLE
            displayStats(stats)
        }
    }

    private fun showResponderStats() {
        val stats = historyManager.getStatsByResponder()
        if (stats.isEmpty()) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.recyclerView.visibility = View.GONE
            binding.statsContainer.visibility = View.GONE
        } else {
            binding.tvEmpty.visibility = View.GONE
            binding.recyclerView.visibility = View.VISIBLE
            binding.statsContainer.visibility = View.GONE
            binding.recyclerView.adapter = StatsAdapter(stats.values.toList(), showIcon = true)
        }
    }

    private fun displayStats(stats: GenreStats) {
        binding.tvStatsName.text = stats.name
        binding.tvStatsTests.text = "${stats.totalTests}回"
        binding.tvStatsAccuracy.text = String.format("%.1f%%", stats.averageAccuracy)
        binding.tvStatsScore.text = String.format("%.1f", stats.averageScore)
        binding.tvStatsQuestions.text = "${stats.totalQuestions}問"
        binding.tvStatsCorrect.text = "${stats.totalCorrect}問"
        binding.tvStatsTime.text = formatTime(stats.averageTime.toLong())
    }

    private fun showHistoryDetail(history: QuizHistoryData) {
        val items = history.questionResults.map { result ->
            val mark = if (result.isCorrect) "⭕" else "❌"
            val correct = if (result.wasSame) "同じ" else "違う"
            val answer = if (result.answeredSame) "同じ" else "違う"
            "$mark 問題${result.questionNumber}\n${result.description}\n正解: $correct / 回答: $answer"
        }.toTypedArray()

        MaterialAlertDialogBuilder(this)
            .setTitle("${history.genre} - 詳細")
            .setItems(items, null)
            .setPositiveButton("閉じる", null)
            .show()
    }

    private fun formatTime(millis: Long): String {
        val seconds = millis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        return if (minutes > 0) "${minutes}分${secs}秒" else "${secs}秒"
    }
}

class HistoryAdapter(
    private val histories: List<QuizHistoryData>,
    private val isSelectionMode: Boolean,
    private val selectedIds: Set<String>,
    private val onClick: (QuizHistoryData) -> Unit,
    private val onLongClick: (QuizHistoryData) -> Unit,
    private val onSelectionChanged: (String, Boolean) -> Unit
) : RecyclerView.Adapter<HistoryAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvGenre: TextView = view.findViewById(R.id.tvGenre)
        val tvDate: TextView = view.findViewById(R.id.tvDate)
        val tvResponder: TextView = view.findViewById(R.id.tvResponder)
        val tvScore: TextView = view.findViewById(R.id.tvScore)
        val tvAccuracy: TextView = view.findViewById(R.id.tvAccuracy)
        val tvTime: TextView = view.findViewById(R.id.tvTime)
        val checkbox: CheckBox? = view.findViewById(R.id.checkbox)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_history, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val history = histories[position]
        val dateFormat = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.getDefault())
        
        holder.tvGenre.text = history.genre
        holder.tvDate.text = dateFormat.format(Date(history.timestamp))
        holder.tvResponder.text = if (history.responderName.isEmpty()) "" else "👤 ${history.responderName}"
        holder.tvResponder.visibility = if (history.responderName.isEmpty()) View.GONE else View.VISIBLE
        holder.tvScore.text = "${history.score}/${history.total}問正解"
        holder.tvAccuracy.text = "${history.accuracy.toInt()}%"
        
        val seconds = history.timeMillis / 1000
        val minutes = seconds / 60
        val secs = seconds % 60
        holder.tvTime.text = if (minutes > 0) "${minutes}分${secs}秒" else "${secs}秒"

        // 選択モードの処理
        holder.checkbox?.visibility = if (isSelectionMode) View.VISIBLE else View.GONE
        holder.checkbox?.isChecked = selectedIds.contains(history.id)
        holder.checkbox?.setOnCheckedChangeListener { _, isChecked ->
            onSelectionChanged(history.id, isChecked)
        }
        
        // 選択中の場合は背景色を変える
        holder.itemView.isActivated = selectedIds.contains(history.id)

        holder.itemView.setOnClickListener { onClick(history) }
        holder.itemView.setOnLongClickListener { 
            onLongClick(history)
            true
        }
    }

    override fun getItemCount() = histories.size
}

class StatsAdapter(
    private val stats: List<GenreStats>,
    private val showIcon: Boolean = false
) : RecyclerView.Adapter<StatsAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvName: TextView = view.findViewById(R.id.tvStatsName)
        val tvTests: TextView = view.findViewById(R.id.tvTestCount)
        val tvAccuracy: TextView = view.findViewById(R.id.tvAvgAccuracy)
        val tvScore: TextView = view.findViewById(R.id.tvAvgScore)
        val tvTime: TextView = view.findViewById(R.id.tvAvgTime)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_stats, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val stat = stats[position]
        holder.tvName.text = if (showIcon) "👤 ${stat.name}" else stat.name
        holder.tvTests.text = "${stat.totalTests}回"
        holder.tvAccuracy.text = String.format("%.1f%%", stat.averageAccuracy)
        holder.tvScore.text = String.format("%.1f", stat.averageScore)
        
        val seconds = (stat.averageTime / 1000).toLong()
        val minutes = seconds / 60
        val secs = seconds % 60
        holder.tvTime.text = if (minutes > 0) "${minutes}分${secs}秒" else "${secs}秒"
    }

    override fun getItemCount() = stats.size
}
