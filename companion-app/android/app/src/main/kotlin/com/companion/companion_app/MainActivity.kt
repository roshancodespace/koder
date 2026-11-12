package com.companion.companion_app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var hidManager: BluetoothKeyboardManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = BluetoothKeyboardManager(applicationContext)
        hidManager = manager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.companion.koder/hid")
            .setMethodCallHandler(manager)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.companion.koder/hid_events")
            .setStreamHandler(manager)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.companion.koder/service")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        startCompanionService()
                        result.success(true)
                    }
                    "stopService" -> {
                        stopCompanionService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startCompanionService() {
        val intent = Intent(this, CompanionForegroundService::class.java).apply {
            action = CompanionForegroundService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopCompanionService() {
        val intent = Intent(this, CompanionForegroundService::class.java).apply {
            action = CompanionForegroundService.ACTION_STOP
        }
        stopService(intent)
    }

    override fun onDestroy() {
        hidManager?.cleanup()
        super.onDestroy()
    }
}
