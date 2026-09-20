// Placement data models.
//
// PlacementInfo mirrors the `placement` object that GET /users/me/memory
// returns once a student has been levelled — the app reads it to decide whether
// the first-run placement flow should run at all.
//
// PlacementTurnResult mirrors the POST /llm/placement-turn response: either
// Zoe's next question (is_complete == false) or the final CEFR assessment
// (is_complete == true). No Flutter/network imports here.

/// The stored placement result, surfaced under `placement` in the memory API.
/// Its presence is the signal that a user has already been placed.
class PlacementInfo {
  final String level; // 'A1'..'C2'
  final String unitLabel; // e.g. 'Finding My Voice'
  final String confidence; // 'low' | 'medium' | 'high'
  final String highlight; // short evidence summary
  final String createdAt; // ISO timestamp

  const PlacementInfo({
    required this.level,
    this.unitLabel = '',
    this.confidence = '',
    this.highlight = '',
    this.createdAt = '',
  });

  factory PlacementInfo.fromJson(Map<String, dynamic> j) => PlacementInfo(
    level: j['level'] as String? ?? '',
    unitLabel: j['unit_label'] as String? ?? '',
    confidence: j['confidence'] as String? ?? '',
    highlight: j['highlight'] as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
  );
}

/// One turn of the placement screening. While the test is running, [reply] is
/// Zoe's next question. When [isComplete] is true the remaining fields carry the
/// final assessment (the backend has already persisted it to memory).
class PlacementTurnResult {
  final String? reply;
  final bool isComplete;
  final String? name;
  final int? age;
  final String? ageGroup;
  final String? level;
  final int? levelNumber;
  final String? levelName; // the unit label (API field `unit_name`)
  final String? levelDescription;
  final String? confidence;
  final String? evidenceSummary;
  final String? zoeRecap;
  final List<String> interests;

  const PlacementTurnResult({
    this.reply,
    this.isComplete = false,
    this.name,
    this.age,
    this.ageGroup,
    this.level,
    this.levelNumber,
    this.levelName,
    this.levelDescription,
    this.confidence,
    this.evidenceSummary,
    this.zoeRecap,
    this.interests = const [],
  });

  factory PlacementTurnResult.fromJson(Map<String, dynamic> j) =>
      PlacementTurnResult(
        reply: j['reply'] as String?,
        isComplete: j['is_complete'] as bool? ?? false,
        name: j['name'] as String?,
        age: (j['age'] as num?)?.toInt(),
        ageGroup: j['age_group'] as String?,
        level: j['level'] as String?,
        levelNumber: (j['level_number'] as num?)?.toInt(),
        // Live API returns `unit_name`; the OpenAPI schema called it
        // `level_name`, so accept either.
        levelName: j['unit_name'] as String? ?? j['level_name'] as String?,
        levelDescription: j['level_description'] as String?,
        confidence: j['confidence'] as String?,
        evidenceSummary: j['evidence_summary'] as String?,
        zoeRecap: j['zoe_recap'] as String?,
        interests: List<String>.from((j['interests'] as List?) ?? const []),
      );
}
