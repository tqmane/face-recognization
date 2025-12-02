package com.tqmane.similarityquiz

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.firebase.database.FirebaseDatabase
import com.tqmane.similarityquiz.databinding.ActivityAdminBinding
import com.tqmane.similarityquiz.databinding.ItemAdminUserBinding
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.*

/**
 * 管理者画面 - 全ユーザーのプレイデータを閲覧
 */
class AdminActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityAdminBinding
    private lateinit var syncManager: FirebaseSyncManager
    private val adapter = UserListAdapter()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    companion object {
        private const val TAG = "AdminActivity"
        // 管理者のUID
        private const val ADMIN_UID = "fwtzsOcnjjWQhwkIRJDfpF0iIY52"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAdminBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        syncManager = FirebaseSyncManager.getInstance(this)
        
        setupToolbar()
        setupRecyclerView()
        checkAccessAndLoad()
    }
    
    private fun setupToolbar() {
        binding.toolbar.setNavigationOnClickListener { finish() }
        binding.btnRefresh.setOnClickListener { loadAllUsersData() }
    }
    
    private fun setupRecyclerView() {
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter
    }
    
    private fun checkAccessAndLoad() {
        val currentUser = syncManager.currentUser
        
        when {
            currentUser == null -> {
                showView(ViewState.NOT_SIGNED_IN)
            }
            currentUser.uid != ADMIN_UID -> {
                showView(ViewState.NO_PERMISSION)
            }
            else -> {
                loadAllUsersData()
            }
        }
    }
    
    private fun loadAllUsersData() {
        showView(ViewState.LOADING)
        
        scope.launch {
            try {
                val database = FirebaseDatabase.getInstance()
                val snapshot = withContext(Dispatchers.IO) {
                    database.reference.child("users").get().await()
                }
                
                if (!snapshot.exists()) {
                    showView(ViewState.EMPTY)
                    return@launch
                }
                
                val usersData = mutableListOf<UserData>()
                
                for (userSnapshot in snapshot.children) {
                    val uid = userSnapshot.key ?: continue
                    val histories = mutableListOf<HistoryData>()
                    
                    val historiesSnapshot = userSnapshot.child("histories")
                    for (historySnapshot in historiesSnapshot.children) {
                        try {
                            val history = parseHistory(historySnapshot.value as? Map<*, *> ?: continue)
                            histories.add(history)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing history", e)
                        }
                    }
                    
                    // タイムスタンプでソート（新しい順）
                    histories.sortByDescending { it.timestamp }
                    
                    usersData.add(UserData(uid, histories))
                }
                
                // プレイ数でソート
                usersData.sortByDescending { it.totalPlays }
                
                if (usersData.isEmpty()) {
                    showView(ViewState.EMPTY)
                } else {
                    updateUI(usersData)
                    showView(ViewState.CONTENT)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load data", e)
                showView(ViewState.EMPTY)
            }
        }
    }
    
    private fun parseHistory(map: Map<*, *>): HistoryData {
        return HistoryData(
            id = map["id"] as? String ?: "",
            genre = map["genre"] as? String ?: "",
            responderName = map["responderName"] as? String ?: "",
            score = (map["score"] as? Number)?.toInt() ?: 0,
            total = (map["total"] as? Number)?.toInt() ?: 0,
            timeMillis = (map["timeMillis"] as? Number)?.toLong() ?: 0,
            timestamp = (map["timestamp"] as? Number)?.toLong() ?: 0
        )
    }
    
    private fun updateUI(usersData: List<UserData>) {
        // サマリー更新
        val totalUsers = usersData.size
        val totalPlays = usersData.sumOf { it.totalPlays }
        val totalQuestions = usersData.sumOf { it.totalQuestions }
        
        binding.tvTotalUsers.text = totalUsers.toString()
        binding.tvTotalPlays.text = totalPlays.toString()
        binding.tvTotalQuestions.text = totalQuestions.toString()
        
        // リスト更新
        adapter.submitList(usersData)
    }
    
    private fun showView(state: ViewState) {
        binding.progressBar.visibility = if (state == ViewState.LOADING) View.VISIBLE else View.GONE
        binding.layoutNotSignedIn.visibility = if (state == ViewState.NOT_SIGNED_IN) View.VISIBLE else View.GONE
        binding.layoutNoPermission.visibility = if (state == ViewState.NO_PERMISSION) View.VISIBLE else View.GONE
        binding.layoutEmpty.visibility = if (state == ViewState.EMPTY) View.VISIBLE else View.GONE
        binding.layoutContent.visibility = if (state == ViewState.CONTENT) View.VISIBLE else View.GONE
    }
    
    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
    
    enum class ViewState {
        LOADING, NOT_SIGNED_IN, NO_PERMISSION, EMPTY, CONTENT
    }
    
    // データクラス
    data class UserData(
        val uid: String,
        val histories: List<HistoryData>
    ) {
        val totalPlays: Int get() = histories.size
        val totalQuestions: Int get() = histories.sumOf { it.total }
        val averageScore: Double get() {
            if (histories.isEmpty()) return 0.0
            val totalScore = histories.sumOf { it.score }
            val totalQ = histories.sumOf { it.total }
            return if (totalQ > 0) (totalScore.toDouble() / totalQ) * 100 else 0.0
        }
        
        val genreStats: Map<String, GenreStats> get() {
            val stats = mutableMapOf<String, GenreStats>()
            for (h in histories) {
                stats.getOrPut(h.genre) { GenreStats() }.add(h)
            }
            return stats
        }
        
        val responderStats: Map<String, GenreStats> get() {
            val stats = mutableMapOf<String, GenreStats>()
            for (h in histories) {
                stats.getOrPut(h.responderName) { GenreStats() }.add(h)
            }
            return stats
        }
    }
    
    data class HistoryData(
        val id: String,
        val genre: String,
        val responderName: String,
        val score: Int,
        val total: Int,
        val timeMillis: Long,
        val timestamp: Long
    )
    
    class GenreStats {
        var plays: Int = 0
        var totalScore: Int = 0
        var totalQuestions: Int = 0
        var totalTimeMillis: Long = 0
        
        fun add(h: HistoryData) {
            plays++
            totalScore += h.score
            totalQuestions += h.total
            totalTimeMillis += h.timeMillis
        }
        
        val averageScore: Double get() = 
            if (totalQuestions > 0) (totalScore.toDouble() / totalQuestions) * 100 else 0.0
        
        val averagePoints: Double get() =
            if (plays > 0) totalScore.toDouble() / plays else 0.0
        
        val averageTimeSeconds: Double get() =
            if (plays > 0) (totalTimeMillis.toDouble() / plays) / 1000 else 0.0
        
        val formattedAverageTime: String get() {
            val seconds = averageTimeSeconds
            val minutes = (seconds / 60).toInt()
            val secs = (seconds % 60).toInt()
            return "$minutes:${secs.toString().padStart(2, '0')}"
        }
    }
    
    // アダプター
    inner class UserListAdapter : RecyclerView.Adapter<UserListAdapter.ViewHolder>() {
        
        private var users: List<UserData> = emptyList()
        private val expandedPositions = mutableSetOf<Int>()
        
        fun submitList(list: List<UserData>) {
            users = list
            expandedPositions.clear()
            notifyDataSetChanged()
        }
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemAdminUserBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
            return ViewHolder(binding)
        }
        
        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(users[position], position)
        }
        
        override fun getItemCount(): Int = users.size
        
        inner class ViewHolder(private val binding: ItemAdminUserBinding) : RecyclerView.ViewHolder(binding.root) {
            
            private val dateFormat = SimpleDateFormat("M/d HH:mm", Locale.getDefault())
            
            fun bind(user: UserData, position: Int) {
                val rank = position + 1
                val isExpanded = expandedPositions.contains(position)
                
                binding.tvRank.text = rank.toString()
                binding.tvUserName.text = "ユーザー ${user.uid.take(8)}..."
                binding.tvUserStats.text = "プレイ数: ${user.totalPlays} | 平均正解率: ${"%.1f".format(user.averageScore)}%"
                
                binding.layoutDetails.visibility = if (isExpanded) View.VISIBLE else View.GONE
                binding.ivExpand.rotation = if (isExpanded) 180f else 0f
                
                binding.layoutHeader.setOnClickListener {
                    if (isExpanded) {
                        expandedPositions.remove(position)
                    } else {
                        expandedPositions.add(position)
                    }
                    notifyItemChanged(position)
                }
                
                if (isExpanded) {
                    bindDetails(user)
                }
            }
            
            private fun bindDetails(user: UserData) {
                // ジャンル別統計
                binding.layoutGenreStats.removeAllViews()
                if (user.genreStats.isEmpty()) {
                    binding.tvGenreLabel.visibility = View.GONE
                    binding.layoutGenreStats.visibility = View.GONE
                } else {
                    binding.tvGenreLabel.visibility = View.VISIBLE
                    binding.layoutGenreStats.visibility = View.VISIBLE
                    addStatsHeader(binding.layoutGenreStats)
                    for ((genre, stats) in user.genreStats) {
                        addDetailedStatRow(binding.layoutGenreStats, genre, stats)
                    }
                }
                
                // 回答者別統計
                binding.layoutResponderStats.removeAllViews()
                if (user.responderStats.isEmpty()) {
                    binding.tvResponderLabel.visibility = View.GONE
                    binding.layoutResponderStats.visibility = View.GONE
                } else {
                    binding.tvResponderLabel.visibility = View.VISIBLE
                    binding.layoutResponderStats.visibility = View.VISIBLE
                    addStatsHeader(binding.layoutResponderStats)
                    for ((responder, stats) in user.responderStats.entries) {
                        val name = responder.ifEmpty { "(未設定)" }
                        addDetailedStatRow(binding.layoutResponderStats, name, stats)
                    }
                }
                
                // 最近のプレイ
                binding.layoutRecentPlays.removeAllViews()
                for (history in user.histories.take(5)) {
                    val label = if (history.responderName.isNotEmpty()) {
                        "${history.genre} (${history.responderName})"
                    } else {
                        history.genre
                    }
                    val date = dateFormat.format(Date(history.timestamp))
                    addStatRow(binding.layoutRecentPlays, label, "${history.score}/${history.total}", date)
                }
            }
            
            private fun addStatsHeader(container: LinearLayout) {
                val row = LinearLayout(container.context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 8
                    }
                }
                
                val headers = listOf("名前" to 2.5f, "回数" to 1f, "正答率" to 1f, "平均点" to 1f, "時間" to 1f)
                for ((text, weight) in headers) {
                    val tv = TextView(container.context).apply {
                        this.text = text
                        textSize = 11f
                        setTextColor(resources.getColor(R.color.text_secondary, null))
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, weight)
                        gravity = if (text == "名前") android.view.Gravity.START else android.view.Gravity.CENTER
                    }
                    row.addView(tv)
                }
                container.addView(row)
                
                // 区切り線
                val divider = View(container.context).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        1
                    ).apply {
                        bottomMargin = 4
                    }
                    setBackgroundColor(resources.getColor(R.color.divider, null))
                }
                container.addView(divider)
            }
            
            private fun addDetailedStatRow(container: LinearLayout, name: String, stats: GenreStats) {
                val row = LinearLayout(container.context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 4
                    }
                }
                
                // 名前
                val tvName = TextView(container.context).apply {
                    text = name
                    textSize = 12f
                    setTextColor(resources.getColor(R.color.text_primary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2.5f)
                    maxLines = 1
                    ellipsize = android.text.TextUtils.TruncateAt.END
                }
                row.addView(tvName)
                
                // 回数
                val tvPlays = TextView(container.context).apply {
                    text = "${stats.plays}"
                    textSize = 12f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = android.view.Gravity.CENTER
                }
                row.addView(tvPlays)
                
                // 正答率
                val tvAccuracy = TextView(container.context).apply {
                    text = "${"%.1f".format(stats.averageScore)}%"
                    textSize = 12f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = android.view.Gravity.CENTER
                }
                row.addView(tvAccuracy)
                
                // 平均点
                val tvPoints = TextView(container.context).apply {
                    text = "${"%.1f".format(stats.averagePoints)}"
                    textSize = 12f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = android.view.Gravity.CENTER
                }
                row.addView(tvPoints)
                
                // 平均時間
                val tvTime = TextView(container.context).apply {
                    text = stats.formattedAverageTime
                    textSize = 12f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = android.view.Gravity.CENTER
                }
                row.addView(tvTime)
                
                container.addView(row)
            }
            
            private fun addStatRow(container: LinearLayout, label: String, value1: String, value2: String) {
                val row = LinearLayout(container.context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 4
                    }
                }
                
                val tvLabel = TextView(container.context).apply {
                    text = label
                    textSize = 13f
                    setTextColor(resources.getColor(R.color.text_primary, null))
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    maxLines = 1
                }
                
                val tvValue1 = TextView(container.context).apply {
                    text = value1
                    textSize = 13f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                }
                
                val tvValue2 = TextView(container.context).apply {
                    text = value2
                    textSize = 13f
                    setTextColor(resources.getColor(R.color.text_secondary, null))
                    setPadding(32, 0, 0, 0)
                }
                
                row.addView(tvLabel)
                row.addView(tvValue1)
                row.addView(tvValue2)
                container.addView(row)
            }
        }
    }
}
