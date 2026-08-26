package com.swipess.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Cap `@capacitor-community/privacy-screen`: the VAP ID card and the document
 * vault ask the OS to keep themselves out of screenshots, screen recordings and
 * the task-switcher thumbnail. On Android that is FLAG_SECURE on the window.
 */
class MainActivity : FlutterActivity() {
    private var privacyChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        privacyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PRIVACY_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        setSecure(true)
                        result.success(true)
                    }
                    "disable" -> {
                        setSecure(false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        privacyChannel?.setMethodCallHandler(null)
        privacyChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun setSecure(secure: Boolean) {
        runOnUiThread {
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private companion object {
        const val PRIVACY_CHANNEL = "swipess/privacy_screen"
    }
}
