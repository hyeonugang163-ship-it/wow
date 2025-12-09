package com.example.voyage

// NOTE: 설계도 v1.1 기준 MethodChannel 진입점으로, PttService start/stop를 isRunning 가드와 try/catch로 보호한다.

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mjtalk.ptt.service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPttService" -> {
                    try {
                        if (PttService.isRunning) {
                            Log.d(
                                "MainActivity",
                                "[PTT][FGS] startPttService ignored, already running",
                            )
                        } else {
                            Log.d(
                                "MainActivity",
                                "[PTT][FGS] startPttService requested",
                            )
                            PttService.startPttService(applicationContext)
                        }
                    } catch (e: Exception) {
                        Log.e(
                            "MainActivity",
                            "[PTT][FGS] startPttService error=$e",
                            e,
                        )
                    }
                    result.success(null)
                }
                "stopPttService" -> {
                    try {
                        Log.d(
                            "MainActivity",
                            "[PTT][FGS] stopPttService requested",
                        )
                        PttService.stopPttService(applicationContext)
                    } catch (e: Exception) {
                        Log.e(
                            "MainActivity",
                            "[PTT][FGS] stopPttService error=$e",
                            e,
                        )
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d("MainActivity", "[PTT][Lifecycle] onPause")
    }

    override fun onStop() {
        super.onStop()
        Log.d("MainActivity", "[PTT][Lifecycle] onStop")
    }

    override fun onDestroy() {
        Log.d("MainActivity", "[PTT][Lifecycle] onDestroy")
        super.onDestroy()
    }
}
