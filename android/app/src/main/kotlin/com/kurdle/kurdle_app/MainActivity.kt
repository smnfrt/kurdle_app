package com.kurdle.kurdle_app

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.kurdle.kurdle_app/haptic"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        val pattern = call.argument<String>("pattern") ?: "light"
                        vibrate(pattern)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getVibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private fun vibrate(pattern: String) {
        val vibrator = getVibrator()
        if (!vibrator.hasVibrator()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = when (pattern) {
                // Taşı kaldırma — kısa güçlü + çok hafif iz
                "tilePickup" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 18, 20, 8), intArrayOf(0, 200, 0, 60), -1
                )
                // Hücre üzerinde geçiş — minimal tık (manyetik his)
                "cellHover" -> VibrationEffect.createOneShot(6, 80)
                // Taşı bırakma/yerleştirme — tok darbeli
                "tileDrop" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 12, 10, 22), intArrayOf(0, 180, 0, 255), -1
                )
                // Taşı rafa geri — hafif bırakış
                "tileReturn" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 10, 15, 8), intArrayOf(0, 120, 0, 60), -1
                )
                // Geçerli kelime — iki yumuşak nabız (başarı)
                "wordValid" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 30, 60, 50), intArrayOf(0, 180, 0, 255), -1
                )
                // Geçersiz kelime — üç sert hızlı titreme (hata)
                "wordInvalid" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 25, 25, 25, 25, 35), intArrayOf(0, 200, 0, 200, 0, 255), -1
                )
                // Skor / hamle gönderme — güçlü tek vuruş
                "submit" -> VibrationEffect.createOneShot(35, 255)
                // Kazanma — yükselen üçlü nabız
                "win" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 40, 50, 60, 50, 90), intArrayOf(0, 150, 0, 200, 0, 255), -1
                )
                // Kaybetme — alçalan ikili nabız
                "lose" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 60, 40, 30), intArrayOf(0, 255, 0, 120), -1
                )
                // Çalma modu aktif — çift nabız uyarı
                "stealToggle" -> VibrationEffect.createWaveform(
                    longArrayOf(0, 20, 30, 20), intArrayOf(0, 200, 0, 200), -1
                )
                // Varsayılan hafif tık
                else -> VibrationEffect.createOneShot(10, 100)
            }
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val ms = when (pattern) {
                "tileDrop", "submit" -> 30L
                "wordInvalid", "win", "lose" -> 60L
                "wordValid" -> 40L
                "cellHover" -> 8L
                else -> 15L
            }
            @Suppress("DEPRECATION")
            vibrator.vibrate(ms)
        }
    }
}
