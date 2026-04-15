package org.navgurukul.ella

import android.util.Log

class WhisperEngine {
    companion object {
        private const val TAG = "WhisperEngine"
        var nativeLoaded = false
            private set

        init {
            try {
                System.loadLibrary("ggml-base")
                System.loadLibrary("ggml-cpu")
                System.loadLibrary("ggml")
                System.loadLibrary("whisper")
                System.loadLibrary("whisper_jni")
                nativeLoaded = true
                Log.d(TAG, "Native libraries loaded")
            } catch (e: UnsatisfiedLinkError) {
                nativeLoaded = false
                Log.e(TAG, "Failed to load native libs: ${e.message}")
            }
        }
    }

    private external fun nativeInit(modelPath: String): Boolean
    private external fun nativeTranscribe(audioData: FloatArray, nSamples: Int): String
    private external fun nativeRelease()

    fun init(modelPath: String): Boolean {
        if (!nativeLoaded) return false
        return try {
            val result = nativeInit(modelPath)
            Log.d(TAG, "Init result: $result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Init failed: ${e.message}")
            false
        }
    }

    fun transcribe(audioData: FloatArray): String {
        if (!nativeLoaded) return ""
        return try {
            nativeTranscribe(audioData, audioData.size)
        } catch (e: Exception) {
            Log.e(TAG, "Transcribe failed: ${e.message}")
            ""
        }
    }

    fun release() {
        if (!nativeLoaded) return
        try { nativeRelease() } catch (_: Exception) {}
    }
}
