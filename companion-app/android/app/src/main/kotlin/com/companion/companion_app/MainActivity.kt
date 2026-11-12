package com.companion.companion_app

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
    }

    override fun onDestroy() {
        hidManager?.cleanup()
        super.onDestroy()
    }
}
