package org.navgurukul.ella.ella_flutter

import android.util.Log

/**
 * Tokenizes text into Piper VITS token IDs using the phoneme_id_map from the config.
 *
 * Token format: BOS(^) + PAD(_) + [char + PAD(_)]... + EOS($)
 * Unknown characters are skipped with a warning.
 */
class PiperTokenizer(config: PiperModelConfig) {
    private val phonemeIdMap: Map<String, List<Long>> = config.phonemeIdMap
    private val padId: Long = phonemeIdMap["_"]?.firstOrNull() ?: 0L
    private val bosId: Long = phonemeIdMap["^"]?.firstOrNull() ?: 1L
    private val eosId: Long = phonemeIdMap["$"]?.firstOrNull() ?: 2L

    companion object {
        private const val TAG = "PiperTokenizer"
    }

    fun tokenize(text: String): LongArray {
        val tokens = mutableListOf<Long>()

        // BOS token + PAD
        tokens.add(bosId)
        tokens.add(padId)

        for (char in text) {
            val key = char.toString()
            val ids = phonemeIdMap[key]
            if (ids != null) {
                tokens.addAll(ids)
                tokens.add(padId)
            } else {
                Log.w(TAG, "Unknown character skipped: '$char' (U+${char.code.toString(16).uppercase()})")
            }
        }

        // EOS token
        tokens.add(eosId)

        return tokens.toLongArray()
    }
}
