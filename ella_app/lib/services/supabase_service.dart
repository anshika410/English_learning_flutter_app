// Supabase CRUD layer.
// Table names and column names match ELLA-Final-Build-Spec.md Part C exactly.
// memory_state has direct columns (level, owned, emerging, …) — NOT a wrapped
// JSONB 'state' column. MemoryState.toJson() keys match the column names.
//
// TESTING-PHASE NOTE: The app writes state directly with the anon key.
// Production-correct: all writes go via a service-role Edge Function.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/child_memory.dart';
import '../models/session.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // ── memory_state ──────────────────────────────────────────────────────────

  Future<MemoryState?> fetchMemory(String childId) async {
    final row = await _client
        .from('memory_state')
        .select()
        .eq('child_id', childId)
        .maybeSingle();
    if (row == null) return null;
    return MemoryState.fromJson(childId, Map<String, dynamic>.from(row));
  }

  Future<void> upsertMemory(MemoryState mem) async {
    await _client.from('memory_state').upsert({
      'child_id': mem.childId,
      ...mem.toJson(), // keys match column names exactly
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── session_logs ──────────────────────────────────────────────────────────

  Future<String> insertSession(SessionLog log) async {
    final row = await _client
        .from('session_logs')
        .insert(log.toJson())
        .select('session_id')
        .single();
    return row['session_id'] as String;
  }

  Future<void> updateSession(
    String sessionId,
    Map<String, dynamic> patch,
  ) async {
    await _client
        .from('session_logs')
        .update(patch)
        .eq('session_id', sessionId);
  }

  // ── transcripts ───────────────────────────────────────────────────────────

  Future<String> insertTranscript({
    required String childId,
    required List<Map<String, dynamic>> turns,
  }) async {
    final row = await _client
        .from('transcripts')
        .insert({'child_id': childId, 'turns': turns})
        .select('transcript_id')
        .single();
    return row['transcript_id'] as String;
  }

  /// Loads the most recent N session_logs for this child, joining
  /// transcripts(turns) so the in-memory SessionLog.transcript field is
  /// populated. Used by ChatNotifier.build() to restore the Session and
  /// History tabs after an app restart.
  Future<List<SessionLog>> fetchRecentSessions({
    required String childId,
    int limit = 20,
  }) async {
    final rows = await _client
        .from('session_logs')
        .select('*, transcripts(turns)')
        .eq('child_id', childId)
        .order('chat_number', ascending: false)
        .limit(limit);

    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final embed = m.remove('transcripts');
      final turns = (embed is Map && embed['turns'] is List)
          ? List<Map<String, dynamic>>.from(
              (embed['turns'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      final log = SessionLog.fromJson(m);
      // SessionLog.fromJson doesn't set `transcript` — overlay it here.
      return SessionLog(
        sessionId: log.sessionId,
        childId: log.childId,
        chatNumber: log.chatNumber,
        level: log.level,
        progressionModel: log.progressionModel,
        turnsTotal: log.turnsTotal,
        topic: log.topic,
        aimedAt: log.aimedAt,
        hitTargets: log.hitTargets,
        judgeScoresRaw: log.judgeScoresRaw,
        stateChanges: log.stateChanges,
        transcriptRef: log.transcriptRef,
        transcript: turns,
      );
    }).toList();
  }

  // ── children ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchChild(String childId) async {
    return _client
        .from('children')
        .select()
        .eq('child_id', childId)
        .maybeSingle();
  }

  /// Idempotent upsert of the demo child row.
  /// child_id == auth_user_id == the anon Supabase auth uid → satisfies all
  /// `_TEST_` RLS policies (which all check auth.uid() = auth_user_id).
  Future<void> ensureChild({
    required String childId,
    String? name,
    String? homeLanguage,
  }) async {
    await _client.from('children').upsert({
      'child_id': childId,
      'auth_user_id': childId,
      'name': name ?? 'Demo',
      'home_language': homeLanguage ?? 'Hindi',
    });
  }
}
