package org.navgurukul.ella

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer

class PiperMethodHandler(
    private val context: Context,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "PiperMethodHandler"
        private const val CHANNEL_NAME = "piper_tts"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME
    )

    private var ortEnvironment: OrtEnvironment? = null
    private var ortSession: OrtSession? = null
    private var modelConfig: PiperModelConfig? = null
    private var tokenizer: PiperTokenizer? = null
    private var phonemizer: TextPhonemizer? = null

    init {
        channel.setMethodCallHandler(this)
        try {
            ortEnvironment = OrtEnvironment.getEnvironment()
            Log.d(TAG, "ONNX Runtime environment created")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create ONNX Runtime environment: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "loadModel" -> handleLoadModel(call, result)
            "synthesize" -> handleSynthesize(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleIsAvailable(result: MethodChannel.Result) {
        val available = ortEnvironment != null
        Log.d(TAG, "isAvailable: $available")
        result.success(available)
    }

    private fun handleLoadModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val modelPath = call.argument<String>("modelPath")
                ?: return result.error("INVALID_ARGS", "modelPath is required", null)
            val configPath = call.argument<String>("configPath")
                ?: return result.error("INVALID_ARGS", "configPath is required", null)

            val env = ortEnvironment
                ?: return result.error("NOT_INITIALIZED", "ONNX Runtime not initialized", null)

            // Close previous session
            ortSession?.close()

            // Parse config
            modelConfig = PiperModelConfig.fromJsonFile(configPath)
            Log.d(TAG, "Config loaded: sampleRate=${modelConfig!!.sampleRate}")

            // Create tokenizer and phonemizer
            tokenizer = PiperTokenizer(modelConfig!!)
            phonemizer = TextPhonemizer()

            // Create ONNX session
            ortSession = env.createSession(modelPath)
            Log.d(TAG, "ONNX session created from: $modelPath")

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "loadModel failed: ${e.message}", e)
            result.error("LOAD_FAILED", "Failed to load model: ${e.message}", null)
        }
    }

    private fun handleSynthesize(call: MethodCall, result: MethodChannel.Result) {
        try {
            val text = call.argument<String>("text")
                ?: return result.error("INVALID_ARGS", "text is required", null)

            val session = ortSession
                ?: return result.error("NO_MODEL", "No model loaded. Call loadModel first.", null)
            val config = modelConfig
                ?: return result.error("NO_MODEL", "No config loaded.", null)
            val tok = tokenizer
                ?: return result.error("NO_MODEL", "Tokenizer not initialized.", null)
            val phon = phonemizer
                ?: return result.error("NO_MODEL", "Phonemizer not initialized.", null)

            val env = ortEnvironment!!

            // 1. Phonemize (identity - just lowercase)
            val phonemized = phon.phonemize(text)
            Log.d(TAG, "Phonemized: '$phonemized'")

            // 2. Tokenize
            val tokenIds = tok.tokenize(phonemized)
            Log.d(TAG, "Token IDs (${tokenIds.size}): ${tokenIds.take(20).toList()}...")

            // 3. Build ONNX input tensors
            // input: int64[1, N]
            val inputTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(tokenIds),
                longArrayOf(1, tokenIds.size.toLong())
            )

            // input_lengths: int64[1]
            val lengthsTensor = OnnxTensor.createTensor(
                env,
                LongBuffer.wrap(longArrayOf(tokenIds.size.toLong())),
                longArrayOf(1)
            )

            // scales: float[3] = [noise_scale, length_scale, noise_w]
            val scalesTensor = OnnxTensor.createTensor(
                env,
                FloatBuffer.wrap(floatArrayOf(config.noiseScale, config.lengthScale, config.noiseW)),
                longArrayOf(3)
            )

            // 4. Run inference
            val inputs = mapOf(
                "input" to inputTensor,
                "input_lengths" to lengthsTensor,
                "scales" to scalesTensor
            )

            val output = session.run(inputs)

            // 5. Extract float audio output
            // Output shape may be [1, 1, sample_count] or [1, 1, 1, sample_count]
            val outputValue = output[0].value
            val audioArray: FloatArray = when (outputValue) {
                is Array<*> -> {
                    // Try to extract the innermost FloatArray
                    var current: Any? = outputValue
                    while (current is Array<*> && current.isNotEmpty()) {
                        current = current[0]
                    }
                    current as? FloatArray ?: FloatArray(0)
                }
                else -> FloatArray(0)
            }
            Log.d(TAG, "Audio samples: ${audioArray.size}")

            // 6. Write WAV file
            val tempDir = context.cacheDir
            val wavFile = File(tempDir, "piper_output_${System.currentTimeMillis()}.wav")
            WavBuilder.writeWavFile(audioArray, config.sampleRate, wavFile.absolutePath)
            Log.d(TAG, "WAV written to: ${wavFile.absolutePath}")

            // Cleanup tensors
            inputTensor.close()
            lengthsTensor.close()
            scalesTensor.close()
            output.close()

            result.success(wavFile.absolutePath)
        } catch (e: Exception) {
            Log.e(TAG, "synthesize failed: ${e.message}", e)
            result.error("SYNTHESIS_FAILED", "Synthesis failed: ${e.message}", null)
        }
    }

    fun dispose() {
        ortSession?.close()
        ortEnvironment?.close()
    }
}
