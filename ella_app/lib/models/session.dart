// session_logs row — column names match ELLA-Final-Build-Spec.md Part C /
// supabase/migrations/001_schema.sql exactly.
//
// `transcript` is an in-memory-only field used by the Glass Box → Session tab.
// It is NOT serialized to Supabase: full transcripts live in the `transcripts`
// table and are referenced from session_logs by `transcript_ref` (uuid FK).

class SessionLog {
  final String? sessionId; // schema PK (uuid). Set by DB on insert.
  final String childId;
  final int chatNumber;
  final String level; // NOT NULL in schema
  final String progressionModel; // NOT NULL in schema ('micro-skill' | 'units')
  final int turnsTotal;
  final String? topic;
  final List<String> aimedAt;
  final List<String> hitTargets;
  final List<Map<String, dynamic>> judgeScoresRaw; // → 'skills_evidenced'
  final List<Map<String, dynamic>> stateChanges;
  final String? transcriptRef; // uuid FK → transcripts.transcript_id

  // In-memory only — never sent to Supabase (lives in `transcripts` table).
  final List<Map<String, dynamic>> transcript;

  const SessionLog({
    this.sessionId,
    required this.childId,
    required this.chatNumber,
    required this.level,
    required this.progressionModel,
    this.turnsTotal = 0,
    this.topic,
    this.aimedAt = const [],
    this.hitTargets = const [],
    this.judgeScoresRaw = const [],
    this.stateChanges = const [],
    this.transcriptRef,
    this.transcript = const [],
  });

  factory SessionLog.fromJson(Map<String, dynamic> j) => SessionLog(
        sessionId: j['session_id'] as String?,
        childId: j['child_id'] as String,
        chatNumber: (j['chat_number'] as num?)?.toInt() ?? 0,
        level: j['level'] as String? ?? 'A1',
        progressionModel: j['progression_model'] as String? ?? 'units',
        turnsTotal: (j['turns_total'] as num?)?.toInt() ?? 0,
        topic: j['topic'] as String?,
        aimedAt: List<String>.from((j['aimed_at'] as List?) ?? []),
        hitTargets: List<String>.from((j['hit_targets'] as List?) ?? []),
        judgeScoresRaw: List<Map<String, dynamic>>.from(
            (j['skills_evidenced'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
                []),
        stateChanges: List<Map<String, dynamic>>.from(
            (j['state_changes'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
                []),
        transcriptRef: j['transcript_ref'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (sessionId != null) 'session_id': sessionId,
        'child_id': childId,
        'chat_number': chatNumber,
        'level': level,
        'progression_model': progressionModel,
        'turns_total': turnsTotal,
        if (topic != null) 'topic': topic,
        'aimed_at': aimedAt,
        'hit_targets': hitTargets,
        'skills_evidenced': judgeScoresRaw,
        'state_changes': stateChanges,
        if (transcriptRef != null) 'transcript_ref': transcriptRef,
      };
}
