package com.tqmane.similarityquiz

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivityFoulEditBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * テストセットの画像を編集（不適切な画像を削除）する画面
 */
class FoulEditActivity : AppCompatActivity() {

    private lateinit var binding: ActivityFoulEditBinding
    private lateinit var adapter: ImageAdapter
    
    private var testSetPath: String = ""
    private var testSetName: String = ""
    private var genreName: String = ""
    private val questions = mutableListOf<QuestionItem>()
    private val selectedIndices = mutableSetOf<Int>()
    
    // 追加ダウンロード用
    private var downloadJob: Job? = null
    private var isDownloading = false
    private val quizManager = OnlineQuizManager()
    
    data class QuestionItem(
        val index: Int,
        val imagePath: String,
        val isSame: Boolean,
        val description: String,
        val fullPath: String
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityFoulEditBinding.inflate(layoutInflater)
        setContentView(binding.root)

        testSetPath = intent.getStringExtra("test_set_path") ?: ""
        testSetName = intent.getStringExtra("test_set_name") ?: "テストセット"
        genreName = intent.getStringExtra("genre") ?: ""

        if (testSetPath.isEmpty()) {
            Toast.makeText(this, "テストセットが見つかりません", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        setupUI()
        loadQuestions()
    }

    private fun setupUI() {
        binding.toolbar.title = "$testSetName の編集"
        binding.toolbar.setNavigationOnClickListener { finish() }

        // グリッドレイアウト（2列）
        binding.recyclerView.layoutManager = GridLayoutManager(this, 2)
        adapter = ImageAdapter(
            questions = questions,
            selectedIndices = selectedIndices,
            onItemClick = { position -> showImagePreview(position) },
            onItemLongClick = { position -> toggleSelection(position) }
        )
        binding.recyclerView.adapter = adapter

        binding.btnDelete.setOnClickListener {
            if (selectedIndices.isEmpty()) {
                Toast.makeText(this, "削除する画像を選択してください", Toast.LENGTH_SHORT).show()
            } else {
                confirmDelete()
            }
        }

        binding.btnSelectAll.setOnClickListener {
            if (selectedIndices.size == questions.size) {
                selectedIndices.clear()
            } else {
                selectedIndices.clear()
                questions.indices.forEach { selectedIndices.add(it) }
            }
            updateUI()
        }

        binding.btnAddMore.setOnClickListener {
            showAddMoreDialog()
        }

        updateUI()
    }

    private fun loadQuestions() {
        val questionsFile = File(testSetPath, "questions.txt")
        if (!questionsFile.exists()) {
            Toast.makeText(this, "問題ファイルが見つかりません", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        questions.clear()
        try {
            questionsFile.readLines().forEachIndexed { index, line ->
                val parts = line.split("|")
                if (parts.size >= 4) {
                    val imagePath = parts[3]
                    val fullPath = File(testSetPath, imagePath).absolutePath
                    if (File(fullPath).exists()) {
                        questions.add(QuestionItem(
                            index = parts[0].toIntOrNull() ?: index,
                            imagePath = imagePath,
                            isSame = parts[1].toBoolean(),
                            description = parts[2],
                            fullPath = fullPath
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            Toast.makeText(this, "読み込みエラー: ${e.message}", Toast.LENGTH_SHORT).show()
        }

        adapter.notifyDataSetChanged()
        updateUI()
    }

    private fun toggleSelection(position: Int) {
        if (selectedIndices.contains(position)) {
            selectedIndices.remove(position)
        } else {
            selectedIndices.add(position)
        }
        adapter.notifyItemChanged(position)
        updateUI()
    }

    private fun showImagePreview(position: Int) {
        val question = questions[position]
        
        // 全画面ダイアログで表示
        val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        dialog.setContentView(R.layout.dialog_image_fullscreen)
        
        val imageView = dialog.findViewById<ImageView>(R.id.fullscreenImage)
        val tvDescription = dialog.findViewById<TextView>(R.id.tvFullscreenDescription)
        val tvAnswer = dialog.findViewById<TextView>(R.id.tvFullscreenAnswer)
        val tvIndex = dialog.findViewById<TextView>(R.id.tvFullscreenIndex)
        val btnToggleSelect = dialog.findViewById<View>(R.id.btnToggleSelect)
        val btnClose = dialog.findViewById<View>(R.id.btnClose)
        
        // 高解像度の画像を読み込む
        val bitmap = BitmapFactory.decodeFile(question.fullPath)
        imageView.setImageBitmap(bitmap)
        
        tvDescription.text = question.description
        tvAnswer.text = "正解: ${if (question.isSame) "同じ" else "違う"}"
        tvAnswer.setTextColor(if (question.isSame) 
            resources.getColor(R.color.ios_green, null) 
            else resources.getColor(R.color.ios_orange, null))
        tvIndex.text = "問題 ${position + 1}"
        
        btnToggleSelect.setOnClickListener {
            toggleSelection(position)
            dialog.dismiss()
        }
        
        btnClose.setOnClickListener {
            dialog.dismiss()
        }
        
        // 画像タップでも閉じる
        imageView.setOnClickListener {
            dialog.dismiss()
        }
        
        dialog.show()
    }

    private fun updateUI() {
        val count = selectedIndices.size
        binding.tvSelectedCount.text = if (count > 0) {
            "${count}件選択中"
        } else {
            "画像を長押しで削除選択"
        }
        binding.tvTotalCount.text = "全${questions.size}問"
        binding.tvHint.text = "💡 タップで画像を拡大表示・長押しで削除選択"
        binding.btnDelete.isEnabled = count > 0
        binding.btnSelectAll.text = if (selectedIndices.size == questions.size) "全選択解除" else "全選択"
    }

    private fun confirmDelete() {
        val count = selectedIndices.size
        MaterialAlertDialogBuilder(this)
            .setTitle("削除確認")
            .setMessage("${count}枚の画像を削除しますか？\n（テストセットの問題数が減少します）")
            .setPositiveButton("削除") { _, _ ->
                deleteSelected()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    private fun deleteSelected() {
        try {
            // 削除対象のインデックス（降順でソート）
            val toDelete = selectedIndices.sortedDescending()
            
            // 画像ファイルを削除
            for (index in toDelete) {
                val question = questions[index]
                File(question.fullPath).delete()
            }

            // questions.txtを更新
            val remaining = questions.filterIndexed { index, _ -> !selectedIndices.contains(index) }
            val questionsFile = File(testSetPath, "questions.txt")
            val newContent = remaining.mapIndexed { newIndex, q ->
                "$newIndex|${q.isSame}|${q.description}|question_$newIndex.png"
            }.joinToString("\n")
            
            // 画像ファイルをリネーム
            remaining.forEachIndexed { newIndex, q ->
                val oldFile = File(q.fullPath)
                val newFile = File(testSetPath, "question_$newIndex.png")
                if (oldFile.absolutePath != newFile.absolutePath && oldFile.exists()) {
                    oldFile.renameTo(newFile)
                }
            }
            
            questionsFile.writeText(newContent)

            // メタデータを更新
            updateMetadata(remaining.size)

            Toast.makeText(this, "${toDelete.size}枚を削除しました", Toast.LENGTH_SHORT).show()
            
            // リストを再読み込み
            selectedIndices.clear()
            loadQuestions()
            
        } catch (e: Exception) {
            Toast.makeText(this, "削除エラー: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    private fun updateMetadata(newCount: Int) {
        val metadataFile = File(testSetPath, "metadata.txt")
        if (metadataFile.exists()) {
            try {
                val lines = metadataFile.readLines().toMutableList()
                if (lines.size >= 2) {
                    lines[1] = newCount.toString()
                    metadataFile.writeText(lines.joinToString("\n"))
                }
            } catch (e: Exception) {
                // 無視
            }
        }
    }

    /**
     * 追加ダウンロードダイアログを表示
     */
    private fun showAddMoreDialog() {
        val options = arrayOf("5問追加", "10問追加", "20問追加", "50問追加")
        val counts = intArrayOf(5, 10, 20, 50)

        MaterialAlertDialogBuilder(this)
            .setTitle("追加ダウンロード")
            .setMessage("現在 ${questions.size} 問あります。\n追加でダウンロードする問題数を選択してください。")
            .setItems(options) { _, which ->
                startAdditionalDownload(counts[which])
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }

    /**
     * 追加ダウンロードを開始
     */
    private fun startAdditionalDownload(addCount: Int) {
        // ジャンルを取得
        val genre = try {
            if (genreName.isNotEmpty()) {
                OnlineQuizManager.Genre.valueOf(genreName)
            } else {
                // メタデータから取得
                val metadataFile = File(testSetPath, "metadata.txt")
                if (metadataFile.exists()) {
                    val genreStr = metadataFile.readLines().firstOrNull() ?: ""
                    OnlineQuizManager.Genre.valueOf(genreStr)
                } else {
                    OnlineQuizManager.Genre.ALL
                }
            }
        } catch (e: Exception) {
            OnlineQuizManager.Genre.ALL
        }

        isDownloading = true
        binding.downloadingOverlay.visibility = View.VISIBLE
        binding.tvDownloadProgress.text = "準備中..."

        downloadJob = lifecycleScope.launch {
            try {
                val startIndex = questions.size
                var successCount = 0
                val maxAttempts = addCount * 3

                // 使用済みURLをクリア（新しい画像を取得するため）
                quizManager.reliableSource.clearUsedUrls()
                quizManager.scraper.clearUsedUrls()

                for (attempt in 0 until maxAttempts) {
                    if (successCount >= addCount) break
                    if (!isDownloading) break

                    withContext(Dispatchers.Main) {
                        binding.tvDownloadProgress.text = "ダウンロード中... $successCount / $addCount"
                    }

                    val config = quizManager.generateRandomQuestion(genre)
                    
                    val bitmap = withContext(Dispatchers.IO) {
                        try {
                            // まず信頼性の高いソースを試す
                            var result = if (config.isSame) {
                                quizManager.reliableSource.createSameImage(config.itemId1)
                            } else {
                                quizManager.reliableSource.createComparisonImage(config.itemId1, config.itemId2)
                            }
                            
                            // 信頼ソースで取得できない場合、Bingフォールバック
                            if (result == null) {
                                result = if (config.isSame) {
                                    quizManager.scraper.createSameImage(config.query1)
                                } else {
                                    quizManager.scraper.createComparisonImage(config.query1, config.query2)
                                }
                            }
                            result
                        } catch (e: Exception) {
                            null
                        }
                    }

                    if (bitmap != null) {
                        val newIndex = startIndex + successCount
                        val imagePath = "question_$newIndex.png"
                        val imageFile = File(testSetPath, imagePath)

                        withContext(Dispatchers.IO) {
                            FileOutputStream(imageFile).use { out ->
                                bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                            }
                            bitmap.recycle()

                            // questions.txtに追加
                            val questionsFile = File(testSetPath, "questions.txt")
                            val newLine = "$newIndex|${config.isSame}|${config.description}|$imagePath"
                            questionsFile.appendText("\n$newLine")
                        }

                        successCount++
                    }
                }

                // メタデータを更新
                withContext(Dispatchers.IO) {
                    updateMetadata(startIndex + successCount)
                }

                // キャッシュクリア
                quizManager.reliableSource.clearCache()
                quizManager.scraper.clearCache()

                withContext(Dispatchers.Main) {
                    isDownloading = false
                    binding.downloadingOverlay.visibility = View.GONE
                    
                    if (successCount > 0) {
                        Toast.makeText(this@FoulEditActivity, "${successCount}問を追加しました", Toast.LENGTH_SHORT).show()
                        selectedIndices.clear()
                        loadQuestions()
                    } else {
                        Toast.makeText(this@FoulEditActivity, "追加ダウンロードに失敗しました", Toast.LENGTH_SHORT).show()
                    }
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    isDownloading = false
                    binding.downloadingOverlay.visibility = View.GONE
                    Toast.makeText(this@FoulEditActivity, "エラー: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        downloadJob?.cancel()
    }

    /**
     * 画像アダプター
     */
    inner class ImageAdapter(
        private val questions: List<QuestionItem>,
        private val selectedIndices: Set<Int>,
        private val onItemClick: (Int) -> Unit,
        private val onItemLongClick: (Int) -> Unit
    ) : RecyclerView.Adapter<ImageAdapter.ViewHolder>() {

        inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val imageView: ImageView = view.findViewById(R.id.ivImage)
            val checkOverlay: View = view.findViewById(R.id.checkOverlay)
            val tvIndex: TextView = view.findViewById(R.id.tvIndex)
            val ivCheck: ImageView = view.findViewById(R.id.ivCheck)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_foul_image, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val question = questions[position]
            
            // 画像読み込み（サムネイル用に縮小）
            val options = BitmapFactory.Options().apply {
                inSampleSize = 2  // 1/2サイズ
            }
            val bitmap = BitmapFactory.decodeFile(question.fullPath, options)
            holder.imageView.setImageBitmap(bitmap)
            
            // インデックス表示
            holder.tvIndex.text = "${position + 1}"
            
            // 選択状態
            val isSelected = selectedIndices.contains(position)
            holder.checkOverlay.visibility = if (isSelected) View.VISIBLE else View.GONE
            holder.ivCheck.visibility = if (isSelected) View.VISIBLE else View.GONE
            holder.itemView.alpha = if (isSelected) 0.7f else 1.0f

            holder.itemView.setOnClickListener { onItemClick(position) }
            holder.itemView.setOnLongClickListener { 
                onItemLongClick(position)
                true
            }
        }

        override fun getItemCount() = questions.size
    }
}
