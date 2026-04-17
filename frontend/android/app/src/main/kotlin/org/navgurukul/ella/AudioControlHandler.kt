package org.navgurukul.ella

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Mutes/unmutes the notification + system sound streams to suppress
 * the Android beep triggered on every SpeechRecognizer start/restart.
 */
class AudioControlHandler(context: Context, flutterEngine: FlutterEngine) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "audio_control")
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var savedNotificationVolume: Int = -1
    private var savedSystemVolume: Int = -1

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "muteBeepStream" -> {
                try {
                    savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                    savedSystemVolume = audioManager.getStreamVolume(AudioManager.STREAM_SYSTEM)
                    audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                    audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("MUTE_FAILED", e.message, null)
                }
            }
            "unmuteBeepStream" -> {
                try {
                    if (savedNotificationVolume >= 0) {
                        audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)
                        savedNotificationVolume = -1
                    }
                    if (savedSystemVolume >= 0) {
                        audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystemVolume, 0)
                        savedSystemVolume = -1
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNMUTE_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        try {
            if (savedNotificationVolume >= 0)
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)
            if (savedSystemVolume >= 0)
                audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystemVolume, 0)
        } catch (_: Exception) {}
        channel.setMethodCallHandler(null)
    }
}
