package com.example.voyage

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class PttService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        when (action) {
            ACTION_START_PTT -> {
                val notification = buildNotification()
                startForeground(NOTIFICATION_ID, notification)
            }
            ACTION_STOP_PTT -> {
                stopForeground(true)
                stopSelf()
            }
            else -> {
                val notification = buildNotification()
                startForeground(NOTIFICATION_ID, notification)
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MJTalk PTT",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("MJTalk PTT 활성화")
            .setContentText("무전 통신이 활성화된 상태입니다.")
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "mjtalk_ptt_channel"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_START_PTT = "com.example.voyage.action.START_PTT"
        const val ACTION_STOP_PTT = "com.example.voyage.action.STOP_PTT"

        fun startPttService(context: Context) {
            val intent = Intent(context, PttService::class.java).apply {
                action = ACTION_START_PTT
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopPttService(context: Context) {
            val intent = Intent(context, PttService::class.java).apply {
                action = ACTION_STOP_PTT
            }
            context.startService(intent)
        }
    }
}

