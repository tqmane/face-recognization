package com.tqmane.similarityquiz

import android.os.Bundle
import android.widget.SeekBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivitySettingsBinding

/**
 * 高度な設定画面
 */
class SettingsActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivitySettingsBinding
    private lateinit var settings: AppSettings
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        settings = AppSettings.getInstance(this)
        
        setupToolbar()
        setupSliders()
        setupSwitch()
        updateSummary()
    }
    
    private fun setupToolbar() {
        binding.toolbar.setNavigationOnClickListener {
            finish()
        }
        
        binding.btnReset.setOnClickListener {
            showResetConfirmDialog()
        }
    }
    
    private fun setupSliders() {
        // 並列ダウンロード数
        binding.sliderParallelDownloads.apply {
            max = 9  // 1-10
            progress = settings.parallelDownloads - 1
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    val value = progress + 1
                    binding.tvParallelDownloadsValue.text = "$value"
                    if (fromUser) settings.parallelDownloads = value
                    updateSummary()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        binding.tvParallelDownloadsValue.text = "${settings.parallelDownloads}"
        
        // キャッシュサイズ
        binding.sliderCacheSize.apply {
            max = 19  // 5-100 (step 5)
            progress = (settings.cacheSize - 5) / 5
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    val value = progress * 5 + 5
                    binding.tvCacheSizeValue.text = "$value"
                    if (fromUser) settings.cacheSize = value
                    updateSummary()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        binding.tvCacheSizeValue.text = "${settings.cacheSize}"
        
        // ダウンロードタイムアウト
        binding.sliderDownloadTimeout.apply {
            max = 11  // 5-60 (step 5)
            progress = (settings.downloadTimeout - 5) / 5
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    val value = progress * 5 + 5
                    binding.tvDownloadTimeoutValue.text = "${value}秒"
                    if (fromUser) settings.downloadTimeout = value
                    updateSummary()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        binding.tvDownloadTimeoutValue.text = "${settings.downloadTimeout}秒"
        
        // 目標画像サイズ
        binding.sliderTargetImageSize.apply {
            max = 12  // 400-1600 (step 100)
            progress = (settings.targetImageSize - 400) / 100
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    val value = progress * 100 + 400
                    binding.tvTargetImageSizeValue.text = "${value}px"
                    if (fromUser) settings.targetImageSize = value
                    updateSummary()
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }
        binding.tvTargetImageSizeValue.text = "${settings.targetImageSize}px"
    }
    
    private fun setupSwitch() {
        binding.switchReliableSources.apply {
            isChecked = settings.useReliableSourcesFirst
            setOnCheckedChangeListener { _, isChecked ->
                settings.useReliableSourcesFirst = isChecked
                updateSummary()
            }
        }
    }
    
    private fun updateSummary() {
        binding.tvSummary.text = """
            • 並列ダウンロード: ${settings.parallelDownloads}
            • キャッシュサイズ: ${settings.cacheSize}
            • タイムアウト: ${settings.downloadTimeout}秒
            • 画像サイズ: ${settings.targetImageSize}px
            • 信頼ソース優先: ${if (settings.useReliableSourcesFirst) "有効" else "無効"}
        """.trimIndent()
    }
    
    private fun showResetConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("設定をリセット")
            .setMessage("すべての設定をデフォルト値に戻しますか？")
            .setPositiveButton("リセット") { _, _ ->
                settings.resetToDefaults()
                refreshUI()
                Toast.makeText(this, "設定をリセットしました", Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun refreshUI() {
        binding.sliderParallelDownloads.progress = settings.parallelDownloads - 1
        binding.tvParallelDownloadsValue.text = "${settings.parallelDownloads}"
        
        binding.sliderCacheSize.progress = (settings.cacheSize - 5) / 5
        binding.tvCacheSizeValue.text = "${settings.cacheSize}"
        
        binding.sliderDownloadTimeout.progress = (settings.downloadTimeout - 5) / 5
        binding.tvDownloadTimeoutValue.text = "${settings.downloadTimeout}秒"
        
        binding.sliderTargetImageSize.progress = (settings.targetImageSize - 400) / 100
        binding.tvTargetImageSizeValue.text = "${settings.targetImageSize}px"
        
        binding.switchReliableSources.isChecked = settings.useReliableSourcesFirst
        
        updateSummary()
    }
}
