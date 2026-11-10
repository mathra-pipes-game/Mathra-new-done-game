package com.mathra.pipes

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mathra/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidId") {
                    val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(id)
                } else {
                    result.notImplemented()
                }
            }
    }
}
