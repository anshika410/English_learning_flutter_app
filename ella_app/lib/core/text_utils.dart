/// Shared text utilities for Ella.

/// Strip markdown syntax to produce plain text safe for TTS playback.
/// Removes bold, italic, inline code, strikethrough, links, headings,
/// and list markers — leaving the readable words only.
String stripMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
      .replaceAll(RegExp(r'__(.+?)__'), r'$1')
      .replaceAll(RegExp(r'_(.+?)_'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
      .replaceAll(RegExp(r'~~(.+?)~~'), r'$1')
      .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
      .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
      .trim();
}
