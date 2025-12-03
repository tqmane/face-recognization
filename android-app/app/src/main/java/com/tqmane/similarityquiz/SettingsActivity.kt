package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.tqmane.similarityquiz.databinding.ActivitySettingsSimpleBinding

/**
 * 設定画面（シンプル版）
 */
class SettingsActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivitySettingsSimpleBinding
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsSimpleBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupToolbar()
        setupSync()
    }
    
    private fun setupToolbar() {
        binding.toolbar.setNavigationOnClickListener {
            finish()
        }
    }
    
    private fun setupSync() {
        binding.btnSync.setOnClickListener {
            startActivity(Intent(this, SyncActivity::class.java))
        }
        binding.btnAdmin.setOnClickListener {
            startActivity(Intent(this, AdminActivity::class.java))
        }
        updateSyncStatus()
    }
    
    private fun updateSyncStatus() {
        val syncManager = FirebaseSyncManager.getInstance(this)
        val user = syncManager.currentUser
        
        if (user != null) {
            binding.tvSyncStatus.text = "✓ ${user.email} でサインイン中"
            binding.tvSyncStatus.setTextColor(getColor(R.color.ios_green))
        } else {
            binding.tvSyncStatus.text = "Googleアカウントでテスト結果を同期"
            binding.tvSyncStatus.setTextColor(getColor(R.color.text_secondary))
        }
    }
    
    override fun onResume() {
        super.onResume()
        updateSyncStatus()
    }
}
