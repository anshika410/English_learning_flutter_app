String normalizeDisplayName(String? raw) {
  if (raw == null) return '';
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) return '';

  return collapsed
      .split(' ')
      .map((part) {
        if (part.isEmpty) return part;
        final lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
