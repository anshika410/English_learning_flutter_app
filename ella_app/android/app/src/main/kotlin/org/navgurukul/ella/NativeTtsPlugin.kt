package org.navgurukul.ella

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class NativeTtsPlugin(private val context: Context, private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler, TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = null
    private var isReady = false
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        tts = TextToSpeech(context, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            tts?.setSpeechRate(0.85f)
            tts?.setPitch(1.1f)
            isReady = true

            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    mainHandler.post { channel.invokeMethod("onTtsStart", null) }
                }

                override fun onDone(utteranceId: String?) {
                    mainHandler.post { channel.invokeMethod("onTtsDone", null) }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    mainHandler.post { channel.invokeMethod("onTtsDone", null) }
                }

                override fun onRangeStart(utteranceId: String?, start: Int, end: Int, frame: Int) {
                    mainHandler.post {
                        channel.invokeMethod("onRangeStart", mapOf(
                            "start" to start,
                            "end" to end
                        ))
                    }
                }
            })
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val text = call.argument<String>("text") ?: ""
                if (isReady && text.isNotEmpty()) {
                    val params = Bundle()
                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "ella_tts")
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "stop" -> {
                tts?.stop()
                result.success(true)
            }
            "isReady" -> {
                result.success(isReady)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        tts?.stop()
        tts?.shutdown()
    }
}
