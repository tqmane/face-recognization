package com.tqmane.similarityquiz

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.EditText
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
        
        // AppSettingsを初期化（まだの場合）
        AppSettings.init(this)
        settings = AppSettings.getInstance()
        
        setupToolbar()
        setupSync()
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
    
    private fun setupSync() {
        binding.btnSync.setOnClickListener {
            startActivity(Intent(this, SyncActivity::class.java))
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
    
    companion object {
        const val MAX_PARALLEL_DOWNLOADS = 50
        const val MAX_CACHE_SIZE = 100
        const val MAX_DOWNLOAD_TIMEOUT = 60
        const val MAX_TARGET_IMAGE_SIZE = 1600
    }
    
    private fun setupSliders() {
        // 並列ダウンロード数
        binding.sliderParallelDownloads.apply {
            max = MAX_PARALLEL_DOWNLOADS - 1  // 1-50
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
        binding.tvParallelDownloadsValue.setOnClickListener {
            showNumberInputDialog(
                title = "並列ダウンロード数",
                currentValue = settings.parallelDownloads,
                min = 1,
                max = MAX_PARALLEL_DOWNLOADS
            ) { value ->
                settings.parallelDownloads = value
                binding.sliderParallelDownloads.progress = value - 1
                binding.tvParallelDownloadsValue.text = "$value"
                updateSummary()
            }
        }
        
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
        binding.tvCacheSizeValue.setOnClickListener {
            showNumberInputDialog(
                title = "キャッシュサイズ",
                currentValue = settings.cacheSize,
                min = 5,
                max = MAX_CACHE_SIZE,
                step = 5
            ) { value ->
                settings.cacheSize = value
                binding.sliderCacheSize.progress = (value - 5) / 5
                binding.tvCacheSizeValue.text = "$value"
                updateSummary()
            }
        }
        
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
        binding.tvDownloadTimeoutValue.setOnClickListener {
            showNumberInputDialog(
                title = "ダウンロードタイムアウト（秒）",
                currentValue = settings.downloadTimeout,
                min = 5,
                max = MAX_DOWNLOAD_TIMEOUT,
                step = 5
            ) { value ->
                settings.downloadTimeout = value
                binding.sliderDownloadTimeout.progress = (value - 5) / 5
                binding.tvDownloadTimeoutValue.text = "${value}秒"
                updateSummary()
            }
        }
        
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
        binding.tvTargetImageSizeValue.setOnClickListener {
            showNumberInputDialog(
                title = "目標画像サイズ（px）",
                currentValue = settings.targetImageSize,
                min = 400,
                max = MAX_TARGET_IMAGE_SIZE,
                step = 100
            ) { value ->
                settings.targetImageSize = value
                binding.sliderTargetImageSize.progress = (value - 400) / 100
                binding.tvTargetImageSizeValue.text = "${value}px"
                updateSummary()
            }
        }
    }
    
    private fun showNumberInputDialog(
        title: String,
        currentValue: Int,
        min: Int,
        max: Int,
        step: Int = 1,
        onValueSet: (Int) -> Unit
    ) {
        val editText = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setText(currentValue.toString())
            hint = "$min - $max"
            setSelection(text.length)
        }
        
        MaterialAlertDialogBuilder(this)
            .setTitle(title)
            .setMessage("$min から $max の範囲で入力してください")
            .setView(editText.apply {
                val padding = (16 * resources.displayMetrics.density).toInt()
                setPadding(padding, padding, padding, padding)
            })
            .setPositiveButton("OK") { _, _ ->
                val inputText = editText.text.toString()
                val inputValue = inputText.toIntOrNull()
                
                if (inputValue == null) {
                    Toast.makeText(this, "数値を入力してください", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }
                
                if (inputValue < min || inputValue > max) {
                    Toast.makeText(this, "$min から $max の範囲で入力してください", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }
                
                // ステップがある場合、最も近い値に調整
                val adjustedValue = if (step > 1) {
                    ((inputValue - min + step / 2) / step) * step + min
                } else {
                    inputValue
                }.coerceIn(min, max)
                
                onValueSet(adjustedValue)
            }
            .setNegativeButton("キャンセル", null)
            .show()
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
