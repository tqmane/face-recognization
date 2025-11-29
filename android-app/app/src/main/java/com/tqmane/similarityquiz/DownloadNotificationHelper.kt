package com.tqmane.similarityquiz

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * ダウンロード進捗通知を管理するヘルパー
 */
class DownloadNotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "download_progress"
        const val CHANNEL_NAME = "ダウンロード進捗"
        const val NOTIFICATION_ID = 1001
        
        // 通知権限リクエストコード
        const val PERMISSION_REQUEST_CODE = 1002
    }

    private val notificationManager = NotificationManagerCompat.from(context)

    init {
        createNotificationChannel()
    }

    /**
     * 通知チャンネルを作成（Android 8.0以上で必要）
     */
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW // 音を鳴らさない
        ).apply {
            description = "テストセットのダウンロード進捗を表示します"
            setShowBadge(false)
        }
        
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    /**
     * 通知権限があるかチェック（Android 13以上で必要）
     */
    fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * ダウンロード開始通知を表示
     */
    fun showDownloadStarted(genreName: String, totalQuestions: Int) {
        if (!hasNotificationPermission()) return

        val intent = Intent(context, TestSetActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("📦 $genreName をダウンロード中")
            .setContentText("準備中...")
            .setProgress(totalQuestions, 0, false)
            .setOngoing(true) // スワイプで消せない
            .setOnlyAlertOnce(true) // 更新時に音を鳴らさない
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // 権限がない場合は無視
        }
    }

    /**
     * ダウンロード進捗を更新
     */
    fun updateProgress(genreName: String, current: Int, total: Int) {
        if (!hasNotificationPermission()) return

        val percent = (current * 100) / total
        
        val intent = Intent(context, TestSetActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("📦 $genreName をダウンロード中")
            .setContentText("$current / $total 問 ($percent%)")
            .setProgress(total, current, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // 権限がない場合は無視
        }
    }

    /**
     * ダウンロード完了通知を表示
     */
    fun showDownloadComplete(genreName: String, questionCount: Int) {
        if (!hasNotificationPermission()) return

        val intent = Intent(context, TestSetActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("✅ ダウンロード完了")
            .setContentText("$genreName ${questionCount}問を保存しました")
            .setProgress(0, 0, false) // プログレスバーを消す
            .setOngoing(false) // スワイプで消せる
            .setAutoCancel(true) // タップで消える
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // 権限がない場合は無視
        }
    }

    /**
     * ダウンロード失敗通知を表示
     */
    fun showDownloadFailed(genreName: String) {
        if (!hasNotificationPermission()) return

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("❌ ダウンロード失敗")
            .setContentText("$genreName のダウンロードに失敗しました")
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // 権限がない場合は無視
        }
    }

    /**
     * ダウンロードキャンセル通知を表示
     */
    fun showDownloadCancelled() {
        if (!hasNotificationPermission()) return

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_delete)
            .setContentTitle("🚫 ダウンロードキャンセル")
            .setContentText("ダウンロードをキャンセルしました")
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // 権限がない場合は無視
        }
    }

    /**
     * 通知をキャンセル
     */
    fun cancelNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
