package org.navgurukul.ella.ella_flutter

import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Converts float audio samples to PCM16 WAV format.
 */
object WavBuilder {

    /**
     * Convert float samples to a complete WAV byte array.
     * Samples are clamped to [-1.0, 1.0] and scaled by 32767.
     */
    fun floatToWav(samples: FloatArray, sampleRate: Int): ByteArray {
        val numChannels = 1
        val bitsPerSample = 16
        val byteRate = sampleRate * numChannels * bitsPerSample / 8
        val blockAlign = numChannels * bitsPerSample / 8
        val dataSize = samples.size * blockAlign
        val headerSize = 44

        val buffer = ByteBuffer.allocate(headerSize + dataSize)
        buffer.order(ByteOrder.LITTLE_ENDIAN)

        // RIFF header
        buffer.put("RIFF".toByteArray())
        buffer.putInt(36 + dataSize)
        buffer.put("WAVE".toByteArray())

        // fmt sub-chunk
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16) // sub-chunk size
        buffer.putShort(1) // PCM format
        buffer.putShort(numChannels.toShort())
        buffer.putInt(sampleRate)
        buffer.putInt(byteRate)
        buffer.putShort(blockAlign.toShort())
        buffer.putShort(bitsPerSample.toShort())

        // data sub-chunk
        buffer.put("data".toByteArray())
        buffer.putInt(dataSize)

        // PCM16 samples
        for (sample in samples) {
            val clamped = sample.coerceIn(-1.0f, 1.0f)
            val pcm16 = (clamped * 32767.0f).toInt().toShort()
            buffer.putShort(pcm16)
        }

        return buffer.array()
    }

    /**
     * Write float samples as a WAV file to the given path.
     */
    fun writeWavFile(samples: FloatArray, sampleRate: Int, outputPath: String) {
        val wavBytes = floatToWav(samples, sampleRate)
        FileOutputStream(File(outputPath)).use { it.write(wavBytes) }
    }
}
