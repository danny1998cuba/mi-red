package com.mired.offline

import io.flutter.embedding.android.FlutterActivity
import android.app.UiModeManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mired.offline/appearance")
            .setMethodCallHandler { call, result ->
                if (call.method != "apply") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val mode = when (call.arguments as? String) {
                    "light" -> UiModeManager.MODE_NIGHT_NO
                    "dark" -> UiModeManager.MODE_NIGHT_YES
                    "system" -> UiModeManager.MODE_NIGHT_AUTO
                    else -> { result.error("INVALID_MODE", "Modo no válido", null); return@setMethodCallHandler }
                }
                try {
                    // API 31+ persists the app-local resource mode for the next system splash.
                    // AUTO clears the app override and follows the device configuration.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        getSystemService(UiModeManager::class.java).setApplicationNightMode(mode)
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("APPEARANCE_UNAVAILABLE", "No se pudo aplicar el tema de arranque", null)
                }
            }
    }
}
