package org.navgurukul.ella.ella_flutter

/**
 * Simple text phonemizer that passes text through as-is (identity function).
 * 
 * Instead of using eSpeak-ng for IPA phonemization, we rely on the
 * phoneme_id_map from the Piper config which maps individual characters
 * (including spaces, punctuation) directly to token IDs.
 * The PiperTokenizer handles the character-to-token-ID mapping.
 */
class TextPhonemizer {
    fun phonemize(text: String): String {
        return text.lowercase()
    }
}
