package com.cricup

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin
import kotlin.math.exp
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cricup/sound"
    private val executor = Executors.newSingleThreadExecutor()
    private var spinPlaying = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSpin" -> {
                    startSpinSound()
                    result.success(null)
                }
                "stopSpin" -> {
                    stopSpinSound()
                    result.success(null)
                }
                "playLanding" -> {
                    playLandingSound()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startSpinSound() {
        spinPlaying = true
        executor.execute {
            val sampleRate = 8000
            // Play a sequence of short tick sounds
            while (spinPlaying) {
                playTick(sampleRate)
                try {
                    Thread.sleep(120) // delay between spins
                } catch (e: InterruptedException) {
                    break
                }
            }
        }
    }

    private fun stopSpinSound() {
        spinPlaying = false
    }

    private fun playTick(sampleRate: Int) {
        val durationMs = 15
        val numSamples = (durationMs * sampleRate) / 1000
        val buffer = ShortArray(numSamples)
        val freq = 1200.0 // high pitched click sound

        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            // sine wave with exponential decay
            val decay = exp(-t * 200.0)
            buffer[i] = (sin(2.0 * Math.PI * freq * t) * 32767.0 * decay).toInt().toShort()
        }

        val audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            buffer.size * 2,
            AudioTrack.MODE_STATIC
        )
        audioTrack.write(buffer, 0, buffer.size)
        audioTrack.play()
        // Wait and release
        try {
            Thread.sleep(durationMs.toLong() + 10)
        } catch (e: Exception) {}
        audioTrack.stop()
        audioTrack.release()
    }

    private fun playLandingSound() {
        spinPlaying = false
        executor.execute {
            val sampleRate = 16000
            val durationMs = 600
            val numSamples = (durationMs * sampleRate) / 1000
            val buffer = ShortArray(numSamples)
            
            // A metallic chime is a combination of frequencies (e.g. 880Hz, 1200Hz, 1500Hz) with exponential decay
            for (i in 0 until numSamples) {
                val t = i.toDouble() / sampleRate
                val decay = exp(-t * 6.0) // decay over 0.6 seconds
                val val1 = sin(2.0 * Math.PI * 880.0 * t)
                val val2 = sin(2.0 * Math.PI * 1200.0 * t) * 0.5
                val val3 = sin(2.0 * Math.PI * 1600.0 * t) * 0.25
                val combined = (val1 + val2 + val3) / 1.75
                buffer[i] = (combined * 32767.0 * decay).toInt().toShort()
            }

            val audioTrack = AudioTrack(
                AudioManager.STREAM_MUSIC,
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                buffer.size * 2,
                AudioTrack.MODE_STATIC
            )
            audioTrack.write(buffer, 0, buffer.size)
            audioTrack.play()
            try {
                Thread.sleep(durationMs.toLong() + 50)
            } catch (e: Exception) {}
            audioTrack.stop()
            audioTrack.release()
        }
    }
}
