package com.example.voyage

// NOTE: 설계도 v1.1 기준 Android Foreground PTT Service로, startForegroundService→startForeground 흐름과 isRunning 가드를 통해 FGS 크래시를 방지한다.

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class PttService : Service() {

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private val audioFocusChangeListener =
        AudioManager.OnAudioFocusChangeListener { focusChange ->
            when (focusChange) {
                AudioManager.AUDIOFOCUS_LOSS,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    Log.d(
                        TAG,
                        "[PTT][AudioFocus] LOSS focusChange=$focusChange, stopping service",
                    )
                    stopSelfSafely("audio_focus_loss")
                }

                AudioManager.AUDIOFOCUS_GAIN -> {
                    Log.d(
                        TAG,
                        "[PTT][AudioFocus] GAIN",
                    )
                }

                else -> {
                    Log.d(
                        TAG,
                        "[PTT][AudioFocus] change=$focusChange",
                    )
                }
            }
        }

    override fun onCreate() {
        super.onCreate()
        isStartingOrRunning = true
        createNotificationChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
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
                    requestAudioFocus()
                }
                ACTION_STOP_PTT -> {
                    stopSelfSafely("action_stop")
                }
                else -> {
                    val notification = buildNotification()
                    startForeground(NOTIFICATION_ID, notification)
                    requestAudioFocus()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "[PTT][FGS] onStartCommand error=$e", e)
            stopSelfSafely("onStartCommand_error")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        abandonAudioFocus()
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

    private fun requestAudioFocus() {
        val manager = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val currentRequest = audioFocusRequest
                if (currentRequest != null) {
                    // 이미 요청된 상태.
                    return
                }
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                val request = AudioFocusRequest.Builder(
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
                    .setAudioAttributes(attributes)
                    .setOnAudioFocusChangeListener(audioFocusChangeListener)
                    .build()
                val result = manager.requestAudioFocus(request)
                if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    audioFocusRequest = request
                    Log.d(TAG, "[PTT][AudioFocus] request granted")
                } else {
                    Log.w(
                        TAG,
                        "[PTT][AudioFocus] request failed result=$result",
                    )
                }
            } else {
                val result = manager.requestAudioFocus(
                    audioFocusChangeListener,
                    AudioManager.STREAM_VOICE_CALL,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
                if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    Log.d(TAG, "[PTT][AudioFocus] request granted (legacy)")
                } else {
                    Log.w(
                        TAG,
                        "[PTT][AudioFocus] request failed (legacy) result=$result",
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "[PTT][AudioFocus] request error=$e", e)
        }
    }

    private fun abandonAudioFocus() {
        val manager = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = audioFocusRequest
                if (request != null) {
                    manager.abandonAudioFocusRequest(request)
                    audioFocusRequest = null
                    Log.d(TAG, "[PTT][AudioFocus] abandon (request)")
                }
            } else {
                manager.abandonAudioFocus(audioFocusChangeListener)
                Log.d(TAG, "[PTT][AudioFocus] abandon (legacy)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[PTT][AudioFocus] abandon error=$e", e)
        }
    }

    private fun stopSelfSafely(reason: String) {
        Log.d(TAG, "[PTT][FGS] stopSelfSafely reason=$reason")
        try {
            try {
                stopForeground(true)
            } catch (e: Exception) {
                Log.e(TAG, "[PTT][FGS] stopForeground error=$e", e)
            }
            abandonAudioFocus()
        } finally {
            isStartingOrRunning = false
            try {
                stopSelf()
            } catch (e: Exception) {
                Log.e(TAG, "[PTT][FGS] stopSelf error=$e", e)
            }
        }
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
