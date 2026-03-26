package org.navgurukul.ella

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

class WhisperRecorderHandler(
    private val context: Context,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WhisperRecorder"
        private const val CHANNEL_NAME = "whisper_recorder"
        private const val SAMPLE_RATE = 16000
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME
    )

    private val whisperEngine = WhisperEngine()
    private var isModelLoaded = false
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val audioBuffer = mutableListOf<Float>()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "initModel" -> handleInitModel(call, result)
            "startRecording" -> handleStartRecording(result)
            "stopRecording" -> handleStopRecording(result)
            else -> result.notImplemented()
        }
    }

    private fun handleIsAvailable(result: MethodChannel.Result) {
        result.success(WhisperEngine.nativeLoaded)
    }

    private fun handleInitModel(call: MethodCall, result: MethodChannel.Result) {
        val modelPath = call.argument<String>("modelPath")
            ?: return result.error("INVALID_ARGS", "modelPath required", null)
        isModelLoaded = whisperEngine.init(modelPath)
        Log.d(TAG, "Model loaded: $isModelLoaded from $modelPath")
        result.success(isModelLoaded)
    }

    @Suppress("MissingPermission")
    private fun handleStartRecording(result: MethodChannel.Result) {
        if (isRecording) {
            result.success(true)
            return
        }

        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize * 2
        )

        audioBuffer.clear()
        isRecording = true
        audioRecord?.startRecording()

        // Read audio in background thread
        thread {
            val buffer = ShortArray(bufferSize / 2)
            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    synchronized(audioBuffer) {
                        for (i in 0 until read) {
                            audioBuffer.add(buffer[i].toFloat() / 32768.0f)
                        }
                    }
                }
            }
        }

        Log.d(TAG, "Recording started")
        result.success(true)
    }

    private fun handleStopRecording(result: MethodChannel.Result) {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        val samples: FloatArray
        synchronized(audioBuffer) {
            samples = audioBuffer.toFloatArray()
            audioBuffer.clear()
        }

        Log.d(TAG, "Recording stopped, ${samples.size} samples")

        if (!isModelLoaded || samples.isEmpty()) {
            result.success("")
            return
        }

        // Run transcription in background
        thread {
            val transcript = whisperEngine.transcribe(samples)
            Log.d(TAG, "Transcript: '$transcript'")
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(transcript.trim())
            }
        }
    }

    fun dispose() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        whisperEngine.release()
    }
}
