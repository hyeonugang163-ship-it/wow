package com.example.voyage

// NOTE: 설계도 v1.1 기준 Android Foreground PTT Service로, startForegroundService→startForeground 흐름과 isRunning 가드를 통해 FGS 크래시를 방지한다.

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class PttService : Service() {

    override fun onCreate() {
        super.onCreate()
        isStartingOrRunning = true
        createNotificationChannel()
        Log.d(TAG, "[PTT][FGS] onCreate, isRunning=true")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        Log.d(TAG, "[PTT][FGS] onStartCommand action=$action, calling startForeground")

        try {
            when (action) {
                ACTION_START_PTT -> {
                    val notification = buildNotification()
                    startForeground(NOTIFICATION_ID, notification)
                }
                ACTION_STOP_PTT -> {
                    stopForeground(true)
                    stopSelf()
                    isStartingOrRunning = false
                }
                else -> {
                    val notification = buildNotification()
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "[PTT][FGS] onStartCommand error=$e", e)
            stopSelf()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isStartingOrRunning = false
        Log.d(TAG, "[PTT][FGS] onDestroy, isRunning=false")
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
        private const val TAG = "PttService"
        private const val CHANNEL_ID = "mjtalk_ptt_channel"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_START_PTT = "com.example.voyage.action.START_PTT"
        const val ACTION_STOP_PTT = "com.example.voyage.action.STOP_PTT"

        @Volatile
        private var isStartingOrRunning: Boolean = false

        val isRunning: Boolean
            get() = isStartingOrRunning

        fun startPttService(context: Context) {
            if (isStartingOrRunning) {
                Log.d(TAG, "[PTT][FGS] startPttService ignored, already running")
                return
            }
            isStartingOrRunning = true

            val intent = Intent(context, PttService::class.java).apply {
                action = ACTION_START_PTT
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                isStartingOrRunning = false
                Log.e(TAG, "[PTT][FGS] startPttService error=$e", e)
            }
        }

        fun stopPttService(context: Context) {
            val intent = Intent(context, PttService::class.java).apply {
                action = ACTION_STOP_PTT
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "[PTT][FGS] stopPttService error=$e", e)
            }
        }
    }
}
