package com.ludomania.game

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ludomania.game/audio"
    private var toneGenMusic: ToneGenerator? = null
    private var toneGenAlarm: ToneGenerator? = null
    private var toneGenSystem: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenMusic = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            toneGenAlarm = ToneGenerator(AudioManager.STREAM_ALARM, 100)
            toneGenSystem = ToneGenerator(AudioManager.STREAM_SYSTEM, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playDiceRoll" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_ACK, 25)
                        toneGenSystem?.startTone(ToneGenerator.TONE_PROP_ACK, 25)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playDiceLand" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_BEEP2, 50)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_PROP_BEEP2, 50)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playHop" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_BEEP, 50)
                        toneGenSystem?.startTone(ToneGenerator.TONE_PROP_BEEP, 50)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playCapture" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_NACK, 200)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_PROP_NACK, 200)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playSnakeBite" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_PROMPT, 300)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_PROP_PROMPT, 300)
                        toneGenSystem?.startTone(ToneGenerator.TONE_PROP_PROMPT, 300)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playRocket" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 300)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 300)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playSlip" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_BEEP2, 200)
                        toneGenSystem?.startTone(ToneGenerator.TONE_PROP_BEEP2, 200)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playSlap" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_NACK, 250)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_PROP_NACK, 250)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playHome" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_PROP_PROMPT, 250)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_PROP_PROMPT, 250)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "playVictory" -> {
                    try {
                        toneGenMusic?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 600)
                        toneGenAlarm?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 600)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
