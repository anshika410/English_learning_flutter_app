package org.navgurukul.ella.ella_flutter

import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class WhisperRecorderHandler(
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WhisperRecorder"
        private const val CHANNEL_NAME = "whisper_recorder"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME
    )

    private var recorder: MediaRecorder? = null
    private var currentPath: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "startRecording" -> handleStartRecording(call, result)
            "stopRecording" -> handleStopRecording(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartRecording(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
                ?: return result.error("INVALID_ARGS", "path is required", null)

            // Stop any existing recording
            stopRecorder()

            currentPath = path
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(android.app.Application())
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioChannels(1)
                setAudioEncodingBitRate(64000)
                setOutputFile(path)
                prepare()
                start()
            }

            Log.d(TAG, "Recording started: $path")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Start recording failed: ${e.message}", e)
            result.error("RECORD_FAILED", "Failed to start recording: ${e.message}", null)
        }
    }

    private fun handleStopRecording(result: MethodChannel.Result) {
        try {
            stopRecorder()
            val path = currentPath
            if (path != null && File(path).exists()) {
                Log.d(TAG, "Recording stopped: $path (${File(path).length()} bytes)")
                result.success(path)
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Stop recording failed: ${e.message}", e)
            result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
        }
    }

    private fun stopRecorder() {
        try {
            recorder?.stop()
            recorder?.release()
        } catch (_: Exception) {}
        recorder = null
    }

    fun dispose() {
        stopRecorder()
    }
}
