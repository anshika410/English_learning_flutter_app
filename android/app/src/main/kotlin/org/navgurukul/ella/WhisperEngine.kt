package org.navgurukul.ella

import android.util.Log

class WhisperEngine {
    companion object {
        private const val TAG = "WhisperEngine"

        init {
            try {
                System.loadLibrary("ggml-base")
                System.loadLibrary("ggml-cpu")
                System.loadLibrary("ggml")
                System.loadLibrary("whisper")
                System.loadLibrary("whisper_jni")
                Log.d(TAG, "Native libraries loaded")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native libraries: ${e.message}")
            }
        }
    }

    external fun nativeInit(modelPath: String): Boolean
    external fun nativeTranscribe(audioData: FloatArray, nSamples: Int): String
    external fun nativeRelease()

    fun init(modelPath: String): Boolean {
        return try {
            val result = nativeInit(modelPath)
            Log.d(TAG, "Init result: $result for $modelPath")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Init failed: ${e.message}")
            false
        }
    }

    fun transcribe(audioData: FloatArray): String {
        return try {
            nativeTranscribe(audioData, audioData.size)
        } catch (e: Exception) {
            Log.e(TAG, "Transcribe failed: ${e.message}")
            ""
        }
    }

    fun release() {
        try { nativeRelease() } catch (_: Exception) {}
    }
}
