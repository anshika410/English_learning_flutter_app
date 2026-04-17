package org.navgurukul.ella

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Custom SpeechRecognizer wrapper that exposes silence tuning extras
 * not available through the speech_to_text Flutter package.
 *
 * Key extras used:
 * - EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS: ms of silence before final result
 * - EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS: ms before partial finalize
 * - EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS: minimum speech before stopping
 */
class SpeechHandler(
    private val context: Context,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SpeechHandler"
        private const val CHANNEL = "speech_handler"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, CHANNEL
    )
    private var recognizer: SpeechRecognizer? = null
    private var isListening = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(SpeechRecognizer.isRecognitionAvailable(context))
            "startListening" -> {
                // Check permission first
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED) {
                    result.error("error_permission", "Microphone permission not granted", null)
                    return
                }
                val silenceMs = call.argument<Int>("silenceMs") ?: 8000
                val possibleSilenceMs = call.argument<Int>("possibleSilenceMs") ?: 5000
                val minSpeechMs = call.argument<Int>("minSpeechMs") ?: 1500
                val locale = call.argument<String>("locale") ?: "en-US"
                startListening(silenceMs, possibleSilenceMs, minSpeechMs, locale, result)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "cancel" -> {
                cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startListening(
        silenceMs: Int,
        possibleSilenceMs: Int,
        minSpeechMs: Int,
        locale: String,
        result: MethodChannel.Result
    ) {
        if (isListening) {
            recognizer?.stopListening()
        }

        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "onReadyForSpeech")
                channel.invokeMethod("onStatus", "listening")
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "onBeginningOfSpeech")
                channel.invokeMethod("onStatus", "speaking")
            }

            override fun onRmsChanged(rmsdB: Float) {
                // Could send audio level if needed
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                Log.d(TAG, "onEndOfSpeech")
                channel.invokeMethod("onStatus", "notListening")
            }

            override fun onError(error: Int) {
                val errorMsg = speechErrorString(error)
                Log.e(TAG, "onError: $errorMsg ($error)")
                isListening = false
                channel.invokeMethod("onError", errorMsg)
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                Log.d(TAG, "onResults: $text")
                isListening = false
                channel.invokeMethod("onResult", mapOf("text" to text, "isFinal" to true))
                channel.invokeMethod("onStatus", "done")
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotEmpty()) {
                    Log.d(TAG, "onPartialResults: $text")
                    channel.invokeMethod("onResult", mapOf("text" to text, "isFinal" to false))
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Key extras for longer silence tolerance
            putExtra("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", silenceMs.toLong())
            putExtra("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", possibleSilenceMs.toLong())
            putExtra("android.speech.extra.SPEECH_INPUT_MINIMUM_LENGTH_MILLIS", minSpeechMs.toLong())
        }

        isListening = true
        recognizer?.startListening(intent)
        Log.d(TAG, "startListening: silence=${silenceMs}ms, possibleSilence=${possibleSilenceMs}ms")
        result.success(true)
    }

    private fun stopListening() {
        isListening = false
        recognizer?.stopListening()
        Log.d(TAG, "stopListening")
    }

    private fun cancel() {
        isListening = false
        recognizer?.cancel()
        Log.d(TAG, "cancel")
    }

    fun dispose() {
        isListening = false
        recognizer?.destroy()
        recognizer = null
        channel.setMethodCallHandler(null)
    }

    private fun speechErrorString(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "error_audio"
        SpeechRecognizer.ERROR_CLIENT -> "error_client"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
        SpeechRecognizer.ERROR_NETWORK -> "error_network"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_recognizer_busy"
        SpeechRecognizer.ERROR_SERVER -> "error_server"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
        else -> "error_unknown_$error"
    }
}
