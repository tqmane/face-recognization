package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivityTestSetDownloadBinding
import com.tqmane.similarityquiz.databinding.ItemTestSetDownloadBinding
import kotlinx.coroutines.launch

/**
 * テストセットダウンロード管理画面
 */
class TestSetDownloadActivity : AppCompatActivity() {

    private lateinit var binding: ActivityTestSetDownloadBinding
    private lateinit var zipService: ZipTestSetService
    private lateinit var adapter: TestSetAdapter
    
    private val downloadedIds = mutableSetOf<String>()
    private val downloadingIds = mutableMapOf<String, Float>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityTestSetDownloadBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        zipService = ZipTestSetService(this)
        
        binding.toolbar.setNavigationOnClickListener { finish() }
        
        adapter = TestSetAdapter()
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter
        
        loadDownloadStatus()
    }
    
    private fun loadDownloadStatus() {
        val downloaded = zipService.getDownloadedTestSets()
        downloadedIds.clear()
        downloadedIds.addAll(downloaded.map { it.id })
        adapter.notifyDataSetChanged()
    }
    
    private fun downloadTestSet(testSet: ZipTestSetService.Companion.TestSetInfo) {
        downloadingIds[testSet.id] = 0f
        adapter.notifyDataSetChanged()
        
        lifecycleScope.launch {
            val success = zipService.downloadTestSet(testSet) { progress ->
                downloadingIds[testSet.id] = progress
                adapter.notifyDataSetChanged()
            }
            
            downloadingIds.remove(testSet.id)
            
            if (success) {
                downloadedIds.add(testSet.id)
                Toast.makeText(
                    this@TestSetDownloadActivity, 
                    "${testSet.displayName} をダウンロードしました", 
                    Toast.LENGTH_SHORT
                ).show()
            } else {
                Toast.makeText(
                    this@TestSetDownloadActivity, 
                    "ダウンロードに失敗しました", 
                    Toast.LENGTH_SHORT
                ).show()
            }
            adapter.notifyDataSetChanged()
        }
    }
    
    private fun deleteTestSet(testSet: ZipTestSetService.Companion.TestSetInfo) {
        MaterialAlertDialogBuilder(this)
            .setTitle("削除確認")
            .setMessage("${testSet.displayName} を削除しますか？")
            .setPositiveButton("削除") { _, _ ->
                zipService.deleteTestSet(testSet.id)
                downloadedIds.remove(testSet.id)
                adapter.notifyDataSetChanged()
                Toast.makeText(this, "${testSet.displayName} を削除しました", Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun startQuiz(testSet: ZipTestSetService.Companion.TestSetInfo) {
        showQuestionCountDialog(testSet)
    }
    
    private fun showQuestionCountDialog(testSet: ZipTestSetService.Companion.TestSetInfo) {
        val options = arrayOf("5問（お試し）", "10問", "15問", "20問")
        val counts = intArrayOf(5, 10, 15, 20)
        
        MaterialAlertDialogBuilder(this)
            .setTitle("問題数を選択")
            .setItems(options) { _, which ->
                val intent = Intent(this, ZipQuizActivity::class.java).apply {
                    putExtra("test_set_id", testSet.id)
                    putExtra("test_set_name", testSet.displayName)
                    putExtra("question_count", counts[which])
                }
                startActivity(intent)
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    inner class TestSetAdapter : RecyclerView.Adapter<TestSetAdapter.ViewHolder>() {
        
        private val testSets = ZipTestSetService.AVAILABLE_TEST_SETS
        
        inner class ViewHolder(val binding: ItemTestSetDownloadBinding) : 
            RecyclerView.ViewHolder(binding.root)
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemTestSetDownloadBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
            return ViewHolder(binding)
        }
        
        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val testSet = testSets[position]
            val isDownloaded = downloadedIds.contains(testSet.id)
            val progress = downloadingIds[testSet.id]
            val isDownloading = progress != null
            
            holder.binding.apply {
                tvName.text = testSet.displayName
                tvDescription.text = testSet.description
                
                // ステータスアイコン
                ivStatus.setImageResource(
                    if (isDownloaded) android.R.drawable.ic_menu_send
                    else android.R.drawable.ic_menu_save
                )
                
                // プログレスバー
                if (isDownloading) {
                    progressBar.visibility = View.VISIBLE
                    progressBar.progress = ((progress ?: 0f) * 100).toInt()
                    btnAction.visibility = View.GONE
                    btnDelete.visibility = View.GONE
                    btnPlay.visibility = View.GONE
                } else {
                    progressBar.visibility = View.GONE
                    
                    if (isDownloaded) {
                        btnAction.visibility = View.GONE
                        btnDelete.visibility = View.VISIBLE
                        btnPlay.visibility = View.VISIBLE
                        
                        btnDelete.setOnClickListener { deleteTestSet(testSet) }
                        btnPlay.setOnClickListener { startQuiz(testSet) }
                    } else {
                        btnAction.visibility = View.VISIBLE
                        btnAction.text = "ダウンロード"
                        btnDelete.visibility = View.GONE
                        btnPlay.visibility = View.GONE
                        
                        btnAction.setOnClickListener { downloadTestSet(testSet) }
                    }
                }
            }
        }
        
        override fun getItemCount() = testSets.size
    }
    
    override fun onResume() {
        super.onResume()
        loadDownloadStatus()
    }
}
