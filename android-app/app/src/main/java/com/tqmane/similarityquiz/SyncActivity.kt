package com.tqmane.similarityquiz

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.tqmane.similarityquiz.databinding.ActivitySyncBinding
import kotlinx.coroutines.launch

/**
 * クラウド同期設定画面
 */
class SyncActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivitySyncBinding
    private lateinit var syncManager: FirebaseSyncManager
    private lateinit var googleSignInClient: GoogleSignInClient
    
    private val signInLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            try {
                val account = task.getResult(ApiException::class.java)
                account.idToken?.let { token ->
                    signInWithFirebase(token)
                } ?: run {
                    Toast.makeText(this, "IDトークンの取得に失敗しました", Toast.LENGTH_SHORT).show()
                }
            } catch (e: ApiException) {
                Toast.makeText(this, "Google認証に失敗しました: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySyncBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        syncManager = FirebaseSyncManager.getInstance(this)
        setupGoogleSignIn()
        setupUI()
        updateUI()
    }
    
    private fun setupGoogleSignIn() {
        // google-services.jsonからWeb Client IDを取得
        val webClientId = getString(R.string.default_web_client_id)
        
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(webClientId)
            .requestEmail()
            .build()
        
        googleSignInClient = GoogleSignIn.getClient(this, gso)
    }
    
    private fun setupUI() {
        binding.toolbar.setNavigationOnClickListener {
            finish()
        }
        
        binding.btnSignIn.setOnClickListener {
            startGoogleSignIn()
        }
        
        binding.btnSignOut.setOnClickListener {
            showSignOutConfirmDialog()
        }
        
        binding.btnUploadAll.setOnClickListener {
            uploadAllHistories()
        }
        
        binding.btnDownload.setOnClickListener {
            // リアルタイム同期で自動的にダウンロードされるが、手動でも可能
            syncManager.setupRealtimeSync()
            Toast.makeText(this, "同期を開始しました", Toast.LENGTH_SHORT).show()
        }
        
        binding.btnClearCloud.setOnClickListener {
            showClearCloudConfirmDialog()
        }
    }
    
    private fun updateUI() {
        val user = syncManager.currentUser
        
        if (user != null) {
            // サインイン済み
            binding.layoutSignedOut.visibility = View.GONE
            binding.layoutSignedIn.visibility = View.VISIBLE
            
            binding.tvUserEmail.text = user.email ?: "メールアドレスなし"
            binding.tvUserName.text = user.displayName ?: "名前なし"
            
            // リアルタイム同期を開始
            syncManager.setupRealtimeSync()
        } else {
            // 未サインイン
            binding.layoutSignedOut.visibility = View.VISIBLE
            binding.layoutSignedIn.visibility = View.GONE
        }
    }
    
    private fun startGoogleSignIn() {
        val signInIntent = googleSignInClient.signInIntent
        signInLauncher.launch(signInIntent)
    }
    
    private fun signInWithFirebase(idToken: String) {
        binding.progressBar.visibility = View.VISIBLE
        
        lifecycleScope.launch {
            syncManager.signInWithGoogle(idToken)
                .onSuccess {
                    Toast.makeText(this@SyncActivity, "サインインしました", Toast.LENGTH_SHORT).show()
                    updateUI()
                }
                .onFailure { e ->
                    Toast.makeText(this@SyncActivity, "サインインに失敗しました: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            
            binding.progressBar.visibility = View.GONE
        }
    }
    
    private fun showSignOutConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("サインアウト")
            .setMessage("サインアウトしますか？\nローカルのデータは保持されます。")
            .setPositiveButton("サインアウト") { _, _ ->
                syncManager.signOut()
                googleSignInClient.signOut()
                updateUI()
                Toast.makeText(this, "サインアウトしました", Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun uploadAllHistories() {
        binding.progressBar.visibility = View.VISIBLE
        
        lifecycleScope.launch {
            syncManager.uploadAllHistories()
                .onSuccess { count ->
                    Toast.makeText(this@SyncActivity, "${count}件のデータをアップロードしました", Toast.LENGTH_SHORT).show()
                }
                .onFailure { e ->
                    Toast.makeText(this@SyncActivity, "アップロードに失敗しました: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            
            binding.progressBar.visibility = View.GONE
        }
    }
    
    private fun showClearCloudConfirmDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle("クラウドデータを削除")
            .setMessage("クラウド上の全てのデータを削除しますか？\nローカルのデータは保持されます。\nこの操作は取り消せません。")
            .setPositiveButton("削除") { _, _ ->
                clearCloudData()
            }
            .setNegativeButton("キャンセル", null)
            .show()
    }
    
    private fun clearCloudData() {
        binding.progressBar.visibility = View.VISIBLE
        
        lifecycleScope.launch {
            syncManager.clearFirebaseHistories()
                .onSuccess {
                    Toast.makeText(this@SyncActivity, "クラウドデータを削除しました", Toast.LENGTH_SHORT).show()
                }
                .onFailure { e ->
                    Toast.makeText(this@SyncActivity, "削除に失敗しました: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            
            binding.progressBar.visibility = View.GONE
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Activityが破棄されても同期は継続（アプリ起動中は同期を維持）
    }
}
