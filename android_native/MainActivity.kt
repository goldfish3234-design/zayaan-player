package com.zayaan.zayaan_player

import android.content.Context
import android.media.AudioManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zayaan/system")
            .setMethodCallHandler { call, result ->
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "getVolume" -> {
                        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                        result.success(if (max > 0) cur.toDouble() / max.toDouble() else 0.0)
                    }
                    "setVolume" -> {
                        val v = (call.argument<Double>("value") ?: 0.0).coerceIn(0.0, 1.0)
                        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(v * max).toInt(), 0)
                        result.success(null)
                    }
                    "getBrightness" -> {
                        val b = window.attributes.screenBrightness
                        if (b >= 0f) {
                            result.success(b.toDouble())
                        } else {
                            val sys = try {
                                Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255.0
                            } catch (e: Exception) {
                                0.5
                            }
                            result.success(sys)
                        }
                    }
                    "setBrightness" -> {
                        val v = (call.argument<Double>("value") ?: 0.5).coerceIn(0.01, 1.0)
                        val lp = window.attributes
                        lp.screenBrightness = v.toFloat()
                        window.attributes = lp
                        result.success(null)
                    }
                    "resetBrightness" -> {
                        val lp = window.attributes
                        lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
