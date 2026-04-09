class PlacementResult {
  final String cefrLevel;
  final String? levelLabel;
  final String highlight;
  final double? confidence;

  const PlacementResult({
    required this.cefrLevel,
    this.levelLabel,
    required this.highlight,
    this.confidence,
  });
}
