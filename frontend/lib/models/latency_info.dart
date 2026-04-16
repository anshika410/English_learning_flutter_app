/// Tracks latency breakdown for a single conversation turn.
class LatencyInfo {
  final Duration? sttDuration; // STT processing time (silence → final transcript)
  final Duration? sttSpeakingDuration; // how long the user spoke
  final Duration llmDuration; // time for LLM API call
  final Duration? ttsDuration; // time for TTS to finish speaking
  final Duration totalDuration; // end-to-end (excluding speaking time)

  const LatencyInfo({
    this.sttDuration,
    this.sttSpeakingDuration,
    required this.llmDuration,
    this.ttsDuration,
    required this.totalDuration,
  });

  String get summary {
    final parts = <String>[];
    if (sttDuration != null) parts.add('STT: ${_fmt(sttDuration!)}');
    parts.add('LLM: ${_fmt(llmDuration)}');
    if (ttsDuration != null) parts.add('TTS: ${_fmt(ttsDuration!)}');
    parts.add('Total: ${_fmt(totalDuration)}');
    return parts.join(' · ');
  }

  static String _fmt(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
}
