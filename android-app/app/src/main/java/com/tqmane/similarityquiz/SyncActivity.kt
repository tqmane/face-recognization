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
        android.util.Log.d("SyncActivity", "signInLauncher結果: resultCode=${result.resultCode}")
        // resultCodeに関わらず、Intentからエラー情報を取得する
        val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
        try {
            val account = task.getResult(ApiException::class.java)
            android.util.Log.d("SyncActivity", "Googleアカウント取得成功: ${account.email}")
            account.idToken?.let { token ->
                android.util.Log.d("SyncActivity", "IDトークン取得成功")
                signInWithFirebase(token)
            } ?: run {
                android.util.Log.e("SyncActivity", "IDトークンがnull")
                Toast.makeText(this, "IDトークンの取得に失敗しました", Toast.LENGTH_LONG).show()
            }
        } catch (e: ApiException) {
            val errorMessage = when (e.statusCode) {
                10 -> "アプリの設定エラー（SHA-1不一致）"
                12500 -> "Google Play開発者サービスの問題"
                12501 -> "ユーザーがキャンセルしました"
                12502 -> "サインインが進行中です"
                7 -> "ネットワークエラー"
                8 -> "内部エラー"
                else -> "不明なエラー"
            }
            android.util.Log.e("SyncActivity", "Google認証エラー: code=${e.statusCode} ($errorMessage), message=${e.message}", e)
            Toast.makeText(this, "Google認証エラー: ${e.statusCode} - $errorMessage", Toast.LENGTH_LONG).show()
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
        
        // 現在の認証状態をログ出力
        android.util.Log.d("SyncActivity", "onCreate: isSignedIn=${syncManager.isSignedIn}, user=${syncManager.currentUser?.email}")
    }
    
    override fun onResume() {
        super.onResume()
        updateUI()
        android.util.Log.d("SyncActivity", "onResume: isSignedIn=${syncManager.isSignedIn}, user=${syncManager.currentUser?.email}")
    }
    
    private fun setupGoogleSignIn() {
        // google-services.jsonからWeb Client IDを取得
        val webClientId = getString(R.string.default_web_client_id)
        android.util.Log.d("SyncActivity", "Web Client ID: $webClientId")
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
        android.util.Log.d("SyncActivity", "updateUI: user=${user?.email}, isSignedIn=${syncManager.isSignedIn}")
        
        if (user != null) {
            // サインイン済み
            binding.layoutSignedOut.visibility = View.GONE
            binding.layoutSignedIn.visibility = View.VISIBLE
            
            binding.tvUserEmail.text = user.email ?: "メールアドレスなし"
            binding.tvUserName.text = user.displayName ?: "名前なし"
            
            android.util.Log.d("SyncActivity", "UI更新: サインイン済み - ${user.email}")
            
            // リアルタイム同期を開始
            syncManager.setupRealtimeSync()
        } else {
            // 未サインイン
            binding.layoutSignedOut.visibility = View.VISIBLE
            binding.layoutSignedIn.visibility = View.GONE
            android.util.Log.d("SyncActivity", "UI更新: 未サインイン")
        }
    }
    
    private fun startGoogleSignIn() {
        android.util.Log.d("SyncActivity", "Google認証を開始")
        val signInIntent = googleSignInClient.signInIntent
        signInLauncher.launch(signInIntent)
    }
    
    private fun signInWithFirebase(idToken: String) {
        android.util.Log.d("SyncActivity", "Firebase認証を開始: token=${idToken.take(20)}...")
        binding.progressBar.visibility = View.VISIBLE
        
        lifecycleScope.launch {
            syncManager.signInWithGoogle(idToken)
                .onSuccess { user ->
                    android.util.Log.d("SyncActivity", "Firebase認証成功: ${user.email}")
                    Toast.makeText(this@SyncActivity, "サインインしました: ${user.email}", Toast.LENGTH_SHORT).show()
                    updateUI()
                }
                .onFailure { e ->
                    android.util.Log.e("SyncActivity", "Firebase認証失敗", e)
                    Toast.makeText(this@SyncActivity, "サインインに失敗しました: ${e.message}", Toast.LENGTH_LONG).show()
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
