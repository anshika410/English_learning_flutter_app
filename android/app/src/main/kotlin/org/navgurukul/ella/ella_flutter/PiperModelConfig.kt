package org.navgurukul.ella.ella_flutter

import com.google.gson.Gson
import com.google.gson.JsonObject
import java.io.File

data class PiperModelConfig(
    val phonemeIdMap: Map<String, List<Long>>,
    val sampleRate: Int,
    val noiseScale: Float,
    val lengthScale: Float,
    val noiseW: Float,
    val numSpeakers: Int = 0,
    val speakerId: Int? = null
) {
    companion object {
        fun fromJsonFile(configPath: String): PiperModelConfig {
            val json = File(configPath).readText()
            val gson = Gson()
            val root = gson.fromJson(json, JsonObject::class.java)

            val audio = root.getAsJsonObject("audio")
            val sampleRate = audio.get("sample_rate").asInt

            val inference = root.getAsJsonObject("inference")
            val noiseScale = inference.get("noise_scale").asFloat
            val lengthScale = inference.get("length_scale").asFloat
            val noiseW = inference.get("noise_w").asFloat

            val phonemeIdMapJson = root.getAsJsonObject("phoneme_id_map")
            val phonemeIdMap = mutableMapOf<String, List<Long>>()
            for ((key, value) in phonemeIdMapJson.entrySet()) {
                val ids = value.asJsonArray.map { it.asLong }
                phonemeIdMap[key] = ids
            }

            val numSpeakers = root.get("num_speakers")?.asInt ?: 0
            val speakerId = root.get("speaker_id")?.asInt

            return PiperModelConfig(
                phonemeIdMap = phonemeIdMap,
                sampleRate = sampleRate,
                noiseScale = noiseScale,
                lengthScale = lengthScale,
                noiseW = noiseW,
                numSpeakers = numSpeakers,
                speakerId = speakerId
            )
        }
    }
}
