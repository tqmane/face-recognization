package com.tqmane.similarityquiz

import android.content.Context
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.database.*
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/**
 * Firebase Realtime Database との同期を管理するクラス
 */
class FirebaseSyncManager private constructor(private val context: Context) {
    
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val database: FirebaseDatabase = FirebaseDatabase.getInstance()
    private val historyManager: HistoryManager = HistoryManager.getInstance(context)
    
    private var syncListener: ValueEventListener? = null
    private var userRef: DatabaseReference? = null
    
    val currentUser: FirebaseUser? get() = auth.currentUser
    val isSignedIn: Boolean get() = currentUser != null
    
    /**
     * Google認証でサインイン
     */
    suspend fun signInWithGoogle(idToken: String): Result<FirebaseUser> {
        return try {
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = auth.signInWithCredential(credential).await()
            result.user?.let {
                setupRealtimeSync()
                Result.success(it)
            } ?: Result.failure(Exception("User is null"))
        } catch (e: Exception) {
            Log.e(TAG, "Google sign in failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * サインアウト
     */
    fun signOut() {
        stopRealtimeSync()
        auth.signOut()
    }
    
    /**
     * リアルタイム同期をセットアップ
     */
    fun setupRealtimeSync() {
        val user = currentUser ?: return
        
        userRef = database.reference.child("users").child(user.uid).child("histories")
        
        syncListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                handleRemoteDataChange(snapshot)
            }
            
            override fun onCancelled(error: DatabaseError) {
                Log.e(TAG, "Database error: ${error.message}")
            }
        }
        
        userRef?.addValueEventListener(syncListener!!)
        Log.d(TAG, "Realtime sync started for user: ${user.uid}")
    }
    
    /**
     * リアルタイム同期を停止
     */
    fun stopRealtimeSync() {
        syncListener?.let { listener ->
            userRef?.removeEventListener(listener)
        }
        syncListener = null
        userRef = null
    }
    
    /**
     * リモートデータの変更を処理
     */
    private fun handleRemoteDataChange(snapshot: DataSnapshot) {
        if (!snapshot.exists()) return
        
        val remoteHistories = mutableListOf<QuizHistoryData>()
        
        for (child in snapshot.children) {
            try {
                val json = child.value as? Map<*, *> ?: continue
                val history = parseHistoryFromFirebase(json)
                remoteHistories.add(history)
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing history: ${e.message}")
            }
        }
        
        // ローカルデータとマージ
        mergeHistories(remoteHistories)
    }
    
    /**
     * Firebaseのデータをパース
     */
    private fun parseHistoryFromFirebase(map: Map<*, *>): QuizHistoryData {
        val questionResults = (map["questionResults"] as? List<*>)?.mapNotNull { qr ->
            val qrMap = qr as? Map<*, *> ?: return@mapNotNull null
            QuestionResultData(
                questionNumber = (qrMap["questionNumber"] as? Number)?.toInt() ?: 0,
                description = qrMap["description"] as? String ?: "",
                isCorrect = qrMap["isCorrect"] as? Boolean ?: false,
                wasSame = qrMap["wasSame"] as? Boolean ?: false,
                answeredSame = qrMap["answeredSame"] as? Boolean ?: false
            )
        } ?: emptyList()
        
        return QuizHistoryData(
            id = map["id"] as? String ?: "",
            genre = map["genre"] as? String ?: "",
            responderName = map["responderName"] as? String ?: "",
            score = (map["score"] as? Number)?.toInt() ?: 0,
            total = (map["total"] as? Number)?.toInt() ?: 0,
            timeMillis = (map["timeMillis"] as? Number)?.toLong() ?: 0,
            timestamp = (map["timestamp"] as? Number)?.toLong() ?: 0,
            questionResults = questionResults
        )
    }
    
    /**
     * ローカルとリモートの履歴をマージ
     */
    private fun mergeHistories(remoteHistories: List<QuizHistoryData>) {
        val localHistories = historyManager.getHistories()
        val localIds = localHistories.map { it.id }.toSet()
        val remoteIds = remoteHistories.map { it.id }.toSet()
        
        // リモートにあってローカルにないものを追加
        val newFromRemote = remoteHistories.filter { it.id !in localIds }
        for (history in newFromRemote) {
            historyManager.saveHistory(history)
        }
        
        if (newFromRemote.isNotEmpty()) {
            Log.d(TAG, "Added ${newFromRemote.size} histories from remote")
        }
    }
    
    /**
     * ローカルの履歴をFirebaseにアップロード
     */
    suspend fun uploadHistory(history: QuizHistoryData): Result<Unit> {
        val user = currentUser ?: return Result.failure(Exception("Not signed in"))
        
        return try {
            val historyRef = database.reference
                .child("users")
                .child(user.uid)
                .child("histories")
                .child(history.id)
            
            val data = mapOf(
                "id" to history.id,
                "genre" to history.genre,
                "responderName" to history.responderName,
                "score" to history.score,
                "total" to history.total,
                "timeMillis" to history.timeMillis,
                "timestamp" to history.timestamp,
                "questionResults" to history.questionResults.map { qr ->
                    mapOf(
                        "questionNumber" to qr.questionNumber,
                        "description" to qr.description,
                        "isCorrect" to qr.isCorrect,
                        "wasSame" to qr.wasSame,
                        "answeredSame" to qr.answeredSame
                    )
                }
            )
            
            historyRef.setValue(data).await()
            Log.d(TAG, "History uploaded: ${history.id}")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Upload failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * 全てのローカル履歴をアップロード
     */
    suspend fun uploadAllHistories(): Result<Int> {
        val user = currentUser ?: return Result.failure(Exception("Not signed in"))
        
        return try {
            val histories = historyManager.getHistories()
            var uploadedCount = 0
            
            for (history in histories) {
                uploadHistory(history).onSuccess {
                    uploadedCount++
                }
            }
            
            Log.d(TAG, "Uploaded $uploadedCount histories")
            Result.success(uploadedCount)
        } catch (e: Exception) {
            Log.e(TAG, "Upload all failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * Firebaseから履歴を削除
     */
    suspend fun deleteHistoryFromFirebase(historyId: String): Result<Unit> {
        val user = currentUser ?: return Result.failure(Exception("Not signed in"))
        
        return try {
            database.reference
                .child("users")
                .child(user.uid)
                .child("histories")
                .child(historyId)
                .removeValue()
                .await()
            
            Log.d(TAG, "History deleted from Firebase: $historyId")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Delete failed", e)
            Result.failure(e)
        }
    }
    
    /**
     * Firebaseから全履歴を削除
     */
    suspend fun clearFirebaseHistories(): Result<Unit> {
        val user = currentUser ?: return Result.failure(Exception("Not signed in"))
        
        return try {
            database.reference
                .child("users")
                .child(user.uid)
                .child("histories")
                .removeValue()
                .await()
            
            Log.d(TAG, "All histories cleared from Firebase")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Clear failed", e)
            Result.failure(e)
        }
    }
    
    companion object {
        private const val TAG = "FirebaseSyncManager"
        
        @Volatile
        private var instance: FirebaseSyncManager? = null
        
        fun getInstance(context: Context): FirebaseSyncManager {
            return instance ?: synchronized(this) {
                instance ?: FirebaseSyncManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
