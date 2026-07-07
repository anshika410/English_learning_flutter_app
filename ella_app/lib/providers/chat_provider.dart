// Chat orchestration — the single in-memory store for the simulator's reactive model.
//
// ChatNotifier loads MemoryState from Supabase (or fresh if not found),
// manages the conversation loop, accumulates snapshots/sessions/history,
// runs dual judging at endChat, and supports auto mode + mode/level/reset.
//
// Non-negotiable: only applyMerge / applyEndChat write owned/emerging/due_next.
// The LLM result (SkillScore list) is passed to the engine, never written directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/engine.dart';
import '../core/skill_data.dart';
import '../core/topic_data.dart';
import '../models/child_memory.dart';
import '../models/history_entry.dart';
import '../models/memory_snapshot.dart';
import '../models/message.dart';
import '../models/session.dart';
import 'garden_provider.dart';
import 'prompts_provider.dart';
import 'service_providers.dart';

const int kAutoMaxTurns = 6;

enum InputMode { voice, text }

enum ChatStatus { idle, zoeThinking, zoeSpeaking, userSpeaking }

class ChatState {
  // Core conversation
  final List<ChatMessage> messages;
  final MemoryState memory;
  final ChatStatus status;
  final InputMode inputMode;
  final List<StateChange> lastChanges;
  final Topic? currentTopic;
  final int turnCount;
  final bool sessionEnded;
  final String? partialStt;

  // Simulator parity additions
  final int
  chatNumber; // 1-based; resets only on resetAll/setLevel/setProgressionModel
  final bool autoMode;
  final int autoStep; // number of auto turns taken so far
  final List<SkillScore> lastJudgeScores; // primary framing
  final List<SkillScore> lastJudgeScoresOther; // alternate framing
  final String
  lastJudgeOtherLabel; // 'units' | 'micro-skill' (empty if no judge yet)
  final List<MemorySnapshot> snapshots;
  final List<SessionLog> sessionLogs;
  final List<HistoryEntry> historyEntries;
  final List<String> aimedAt;
  final List<String> hitTargets;
  final bool liveLlmLastCall;
  final String? activeSessionId;
  // Skills the server aimed this session at (from POST /session → aimed_at).
  // Authoritative aim list when online; empty in offline fallback.
  final List<String> serverAimedAt;

  // Most recent Supabase failure (auth, ensureChild, endChat persist).
  // Surfaced as a red banner in Glass Box → Memory tab.
  final String? lastSyncError;

  const ChatState({
    this.messages = const [],
    required this.memory,
    this.status = ChatStatus.idle,
    this.inputMode = InputMode.voice,
    this.lastChanges = const [],
    this.currentTopic,
    this.turnCount = 0,
    this.sessionEnded = false,
    this.partialStt,
    this.chatNumber = 1,
    this.autoMode = false,
    this.autoStep = 0,
    this.lastJudgeScores = const [],
    this.lastJudgeScoresOther = const [],
    this.lastJudgeOtherLabel = '',
    this.snapshots = const [],
    this.sessionLogs = const [],
    this.historyEntries = const [],
    this.aimedAt = const [],
    this.hitTargets = const [],
    this.liveLlmLastCall = true,
    this.activeSessionId,
    this.serverAimedAt = const [],
    this.lastSyncError,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    MemoryState? memory,
    ChatStatus? status,
    InputMode? inputMode,
    List<StateChange>? lastChanges,
    Topic? currentTopic,
    bool clearTopic = false,
    int? turnCount,
    bool? sessionEnded,
    String? partialStt,
    bool clearPartialStt = false,
    bool clearChanges = false,
    int? chatNumber,
    bool? autoMode,
    int? autoStep,
    List<SkillScore>? lastJudgeScores,
    List<SkillScore>? lastJudgeScoresOther,
    String? lastJudgeOtherLabel,
    List<MemorySnapshot>? snapshots,
    List<SessionLog>? sessionLogs,
    List<HistoryEntry>? historyEntries,
    List<String>? aimedAt,
    List<String>? hitTargets,
    bool? liveLlmLastCall,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    List<String>? serverAimedAt,
    String? lastSyncError,
    bool clearSyncError = false,
  }) => ChatState(
    messages: messages ?? this.messages,
    memory: memory ?? this.memory,
    status: status ?? this.status,
    inputMode: inputMode ?? this.inputMode,
    lastChanges: clearChanges ? const [] : (lastChanges ?? this.lastChanges),
    currentTopic: clearTopic ? null : (currentTopic ?? this.currentTopic),
    turnCount: turnCount ?? this.turnCount,
    sessionEnded: sessionEnded ?? this.sessionEnded,
    partialStt: clearPartialStt ? null : (partialStt ?? this.partialStt),
    chatNumber: chatNumber ?? this.chatNumber,
    autoMode: autoMode ?? this.autoMode,
    autoStep: autoStep ?? this.autoStep,
    lastJudgeScores: lastJudgeScores ?? this.lastJudgeScores,
    lastJudgeScoresOther: lastJudgeScoresOther ?? this.lastJudgeScoresOther,
    lastJudgeOtherLabel: lastJudgeOtherLabel ?? this.lastJudgeOtherLabel,
    snapshots: snapshots ?? this.snapshots,
    sessionLogs: sessionLogs ?? this.sessionLogs,
    historyEntries: historyEntries ?? this.historyEntries,
    aimedAt: aimedAt ?? this.aimedAt,
    hitTargets: hitTargets ?? this.hitTargets,
    liveLlmLastCall: liveLlmLastCall ?? this.liveLlmLastCall,
    activeSessionId: clearActiveSessionId
        ? null
        : (activeSessionId ?? this.activeSessionId),
    serverAimedAt: serverAimedAt ?? this.serverAimedAt,
    lastSyncError: clearSyncError
        ? null
        : (lastSyncError ?? this.lastSyncError),
  );

  List<ConvMessage> get convHistory => messages
      .where((m) => m.sender != MessageSender.system)
      .map(
        (m) => ConvMessage(
          role: m.sender == MessageSender.zoe ? 'zoe' : 'user',
          text: m.text,
        ),
      )
      .toList();
}

// Nil UUID — used as a placeholder childId when we cannot sign in.
// Format is valid so it satisfies Postgres uuid columns; FK / RLS will still
// reject it, which is exactly why we ALSO skip Supabase writes when offline.
const String _kOfflineChildId = '00000000-0000-0000-0000-000000000000';

class ChatNotifier extends AsyncNotifier<ChatState> {
  // Resolved at build() time. Equals the Supabase auth uid when sign-in
  // succeeds; equals _kOfflineChildId otherwise.
  late String _childId;
  // true when auth+ensureChild succeeded — gates Supabase writes in endChat.
  bool _online = false;

  String get childId => _childId;
  bool get online => _online;

  @override
  Future<ChatState> build() async {
    // Init STT/TTS regardless of network state.
    final tts = ref.read(ttsProvider);
    await tts.initialize();
    final stt = ref.read(sttProvider);
    await stt.initialize();

    final api = ref.read(ellaApiServiceProvider);

    String? syncError;
    MemoryState mem;
    List<SessionLog> sessions = const [];
    List<HistoryEntry> history = const [];
    int nextChatNumber = 1;

    try {
      _childId = await api.getCachedUserId() ?? _kOfflineChildId;

      // Make sure a `children` row exists for this uid (FK source).
      // User creation is handled by POST /auth/google or magic link.

      // Canonical load order: auth → memory → garden (mirrors the server flow).
      // Resume memory from persisted state if any, else fresh.
      mem = await api.getUserMemory();
      // The server returns its own due_next, but the engine's due_next-stage
      // rules (engine.dart) are authoritative on the frontend. Recompute over
      // the server's owned/emerging so those rules drive the due_next display
      // and judge framing. (Live Zoe targeting is still server-side.)
      mem = mem.copyWith(
        dueNext: targetsListFor(mem, mem.progressionModel, mem.level),
      );
      nextChatNumber = mem.chatCount > 0 ? mem.chatCount + 1 : 1;
      _online = true;

      // Warm the garden right after memory so the Garden tab is ready and the
      // call sequence matches the server contract. Best-effort: a failure here
      // must not block the chat. The Garden tab reads gardenProvider, which is
      // invalidated after every endChat to pull fresh growth.
      try {
        await api.getGarden();
      } catch (_) {}
    } catch (e) {
      // Offline-only mode. App still works in memory; Glass Box shows the error.
      // No Supabase writes will be attempted while _online is false.
      _online = false;
      _childId = _kOfflineChildId;
      mem = MemoryState.fresh('A1', childId: _childId);
      syncError = 'Ella API init failed: $e';
    }

    return ChatState(
      memory: mem,
      sessionLogs: sessions,
      historyEntries: history,
      chatNumber: nextChatNumber,
      lastSyncError: syncError,
    );
  }

  // ── Placement completion ──────────────────────────────────────────────────

  /// Called after the first-run placement screening completes. The backend has
  /// already persisted the placement (level + `placement` object), so re-fetch
  /// memory, recompute due_next locally (engine rules are authoritative on the
  /// frontend), update in-memory state, and invalidate the garden so it renders
  /// at the new level. Best-effort: a failure just leaves the current state.
  Future<void> refreshAfterPlacement() async {
    if (!_online) return;
    try {
      final api = ref.read(ellaApiServiceProvider);
      var mem = await api.getUserMemory();
      mem = mem.copyWith(
        dueNext: targetsListFor(mem, mem.progressionModel, mem.level),
      );
      final cur = state.requireValue;
      state = AsyncValue.data(
        cur.copyWith(
          memory: mem,
          chatNumber: mem.chatCount > 0 ? mem.chatCount + 1 : 1,
          clearSyncError: true,
        ),
      );
      // Garden tab reads gardenProvider — invalidate so it refetches at the new
      // placement level the next time it's shown.
      ref.invalidate(gardenProvider);
    } catch (e) {
      final cur = state.requireValue;
      state = AsyncValue.data(
        cur.copyWith(lastSyncError: 'Post-placement memory refresh failed: $e'),
      );
    }
  }

  // ── Session start ────────────────────────────────────────────────────────

  Future<void> startSession({Topic? topicOverride}) async {
    final cur = state.requireValue;
    // If returning to a new session, clear old topic and reset state
    if (cur.messages.isEmpty && cur.currentTopic != null) {
      state = AsyncValue.data(cur.copyWith(clearTopic: true));
    }
    if (cur.sessionEnded || cur.messages.isNotEmpty) return;

    // A tapped home-screen topic overrides the engine's pick; otherwise the
    // engine chooses the next topic as before.
    final topic = topicOverride ?? pickTopic(cur.memory);
    String? backendSessionId;
    String? starter;
    List<String> serverAimedAt = const [];
    String? syncError;
    if (_online) {
      try {
        final api = ref.read(ellaApiServiceProvider);
        final conversation = await api.createConversation(topic: topic?.topic);
        backendSessionId = conversation['session_id'] as String?;
        starter = conversation['starter'] as String?;
        serverAimedAt = List<String>.from(
          (conversation['aimed_at'] as List?) ?? const [],
        );
        if (starter == null || starter.trim().isEmpty) {
          starter = await api.conversationStarter(topic: topic?.topic);
        }
      } catch (e) {
        syncError = 'Create conversation failed: $e';
      }
    }

    state = AsyncValue.data(
      cur.copyWith(
        status: ChatStatus.zoeThinking,
        currentTopic: topic,
        activeSessionId: backendSessionId,
        serverAimedAt: serverAimedAt,
        lastSyncError: syncError,
        clearSyncError: syncError == null,
      ),
    );

    if (starter != null && starter.trim().isNotEmpty) {
      final zoeMsg = ChatMessage(
        sender: MessageSender.zoe,
        text: starter.trim(),
      );
      state = AsyncValue.data(
        state.requireValue.copyWith(
          messages: [zoeMsg],
          // Mark Zoe as speaking while the greeting TTS plays so the mascot
          // opens its mouth (mirrors _zoeTurn); reset to idle when done.
          status: ChatStatus.zoeSpeaking,
          liveLlmLastCall: true,
        ),
      );
      try {
        final tts = ref.read(ttsProvider);
        await tts.speak(zoeMsg.text);
      } catch (_) {}
      state = AsyncValue.data(
        state.requireValue.copyWith(status: ChatStatus.idle),
      );
      return;
    }

    await _zoeTurn([], topic);
  }

  // ── User turn ─────────────────────────────────────────────────────────────

  Future<void> sendUserTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final cur = state.requireValue;
    if (cur.sessionEnded) return;
    // Accept a turn from idle (typed) or userSpeaking (STT just finished).
    // Committing directly from userSpeaking lets the caption go partial → the
    // child's committed text in one step, instead of briefly dropping to idle
    // and flashing Zoe's previous line. Reject while Zoe is thinking/speaking.
    if (cur.status != ChatStatus.idle &&
        cur.status != ChatStatus.userSpeaking) {
      return;
    }

    final userMsg = ChatMessage(sender: MessageSender.child, text: trimmed);
    final msgs = [...cur.messages, userMsg];

    state = AsyncValue.data(
      cur.copyWith(
        messages: msgs,
        status: ChatStatus.zoeThinking,
        turnCount: cur.turnCount + 1,
        clearPartialStt: true,
      ),
    );

    await _zoeTurn(state.requireValue.convHistory, cur.currentTopic);
  }

  // ── Auto mode ─────────────────────────────────────────────────────────────

  void setAutoMode(bool on) {
    final cur = state.requireValue;
    state = AsyncValue.data(cur.copyWith(autoMode: on));
  }

  Future<void> autoTurn() async {
    final cur = state.requireValue;
    if (cur.status != ChatStatus.idle || cur.sessionEnded) return;
    if (cur.autoStep >= kAutoMaxTurns) {
      await endChat();
      return;
    }
    state = AsyncValue.data(
      cur.copyWith(status: ChatStatus.zoeThinking, autoStep: cur.autoStep + 1),
    );
    try {
      final llm = ref.read(llmServiceProvider);
      final reply = await llm.mockLearner(
        history: cur.convHistory,
        level: cur.memory.level,
      );
      state = AsyncValue.data(
        state.requireValue.copyWith(
          status: ChatStatus.idle,
          liveLlmLastCall: true,
        ),
      );
      await sendUserTurn(reply);
    } catch (e) {
      // Fallback to canned replies if the proxy is unreachable
      const mockKid = [
        'My name is Priya.',
        'I am eleven.',
        'Yes, one sister. Her name Anjali.',
        'I like cricket and she like dancing.',
        'Because it is fun.',
        'Yesterday I go to school.',
      ];
      final reply = mockKid[(cur.autoStep) % mockKid.length];
      state = AsyncValue.data(
        state.requireValue.copyWith(
          status: ChatStatus.idle,
          liveLlmLastCall: false,
        ),
      );
      await sendUserTurn(reply);
    }
  }

  // ── End chat + DUAL judge ─────────────────────────────────────────────────

  Future<void> endChat() async {
    final cur = state.requireValue;
    if (cur.sessionEnded || cur.messages.isEmpty) return;

    state = AsyncValue.data(cur.copyWith(status: ChatStatus.zoeThinking));

    final mem = cur.memory;
    final mode = mem.progressionModel;
    final chatNumber = cur.chatNumber;

    String? syncError;
    List<SkillScore> primaryScores = const [];
    List<SkillScore> otherScores = const [];
    List<StateChange> effectiveChanges = const [];
    MemoryState newMem;
    List<String> aimed;
    List<String> hitTargets;
    var liveLlm = false;

    if (_online && cur.activeSessionId != null) {
      // ── Ella API is the single backend: the server runs the judge AND the
      // deterministic merge, then persists the transcript + new memory. ───────
      try {
        final api = ref.read(ellaApiServiceProvider);
        // End-chat flow (matches the server contract / network log order):
        //   judge → memory → garden → session-log.
        final analysis = await api.judge(
          sessionId: cur.activeSessionId!,
          history: cur.convHistory,
          topic: cur.currentTopic?.topic ?? 'Free Talk',
          level: mem.level,
          progressionModel: mode,
        );
        primaryScores = analysis.scores;
        effectiveChanges = analysis.changes;
        aimed = analysis.aimedAt.isNotEmpty
            ? analysis.aimedAt
            : (cur.serverAimedAt.isNotEmpty
                  ? cur.serverAimedAt
                  : mem.dueNext.flat);
        hitTargets = analysis.hitTargets;
        liveLlm = true;

        // The server already merged state — re-fetch owned/emerging as the
        // source of truth, but recompute due_next locally so the engine's
        // due_next-stage rules (engine.dart) drive the next stage.
        final serverMem = (await api.getUserMemory()).copyWith(
          chatCount: mem.chatCount + 1,
          progressionModel: mode,
        );
        newMem = serverMem.copyWith(
          dueNext: targetsListFor(serverMem, mode, serverMem.level),
        );

        // Refresh the garden, then pull the canonical session log. Best-effort —
        // neither should block ending the chat.
        try {
          await api.getGarden();
        } catch (_) {}
        try {
          await api.getSessionLog(cur.activeSessionId!);
        } catch (_) {}
        // The Garden tab reads gardenProvider; invalidate so it refetches the
        // updated growth the next time it's shown.
        ref.invalidate(gardenProvider);
      } catch (e) {
        syncError = 'Session analysis API failed: $e';
        // Degraded fallback — merge whatever scores we have locally so the
        // user can still move on. primaryScores is empty here → no changes.
        final merge = applyMerge(mem, primaryScores, mem.level);
        effectiveChanges = merge.changes;
        aimed = cur.serverAimedAt.isNotEmpty
            ? cur.serverAimedAt
            : mem.dueNext.flat;
        hitTargets = aimed
            .where(
              (id) => primaryScores.any(
                (s) => s.id == id && s.confidence >= kFloor,
              ),
            )
            .toList();
        newMem = applyEndChat(
          mem: mem,
          mergeResult: merge,
          turnCount: cur.turnCount,
          chatNumber: chatNumber,
          usedTopic: cur.currentTopic,
          progressionModel: mode,
          level: mem.level,
        ).copyWith(chatCount: mem.chatCount + 1);
      }
    } else {
      // ── Offline fallback: local LLM judge + deterministic engine merge.
      // LLM never writes state — applyMerge/applyEndChat own that. ────────────
      final prompts = ref.read(promptsOverrideProvider);
      final primaryPrompt = buildJudgePrompt(
        level: mem.level,
        skillIds: _idsForFraming(mem, mode),
        history: cur.convHistory,
        prompts: prompts,
      );
      final otherPrompt = buildJudgePrompt(
        level: mem.level,
        skillIds: _idsForFraming(mem, mode),
        history: cur.convHistory,
        prompts: prompts,
      );
      final llm = ref.read(llmServiceProvider);
      final results = await Future.wait([
        llm.judge(primaryPrompt).catchError((Object _) => <SkillScore>[]),
        llm.judge(otherPrompt).catchError((Object _) => <SkillScore>[]),
      ]);
      primaryScores = results[0];
      otherScores = results[1];
      liveLlm = primaryScores.isNotEmpty;

      final merge = applyMerge(mem, primaryScores, mem.level);
      effectiveChanges = merge.changes;
      aimed = mem.dueNext.flat;
      hitTargets = aimed
          .where(
            (id) =>
                primaryScores.any((s) => s.id == id && s.confidence >= kFloor),
          )
          .toList();
      newMem = applyEndChat(
        mem: mem,
        mergeResult: merge,
        turnCount: cur.turnCount,
        chatNumber: chatNumber,
        usedTopic: cur.currentTopic,
        progressionModel: mode,
        level: mem.level,
      ).copyWith(chatCount: mem.chatCount + 1);
      if (!_online) {
        syncError = 'Offline mode — using local engine (Ella API unavailable).';
      }
    }

    final judgeFailed = primaryScores.isEmpty;

    // Build the transcript as {speaker,text} maps for the Session tab JSON.
    // (The server already stored the canonical transcript via /turn.)
    final transcript = cur.messages
        .where((m) => m.sender != MessageSender.system)
        .map(
          (m) => {
            'speaker': m.sender == MessageSender.zoe ? 'zoe' : 'learner',
            'text': m.text,
          },
        )
        .toList();

    final scoresJson = primaryScores.map((s) => s.toJson()).toList();
    final changesJson = effectiveChanges
        .map((c) => {'id': c.id, 'from': c.from, 'to': c.to})
        .toList();

    // The Ella session id is the persistence reference — the server owns the
    // transcript + analysis. No Supabase writes in single-backend mode.
    final sessionId = cur.activeSessionId;
    final transcriptId = cur.activeSessionId;

    // In-memory session record (also drives Glass Box → Session tab).
    final inMemSession = SessionLog(
      sessionId: sessionId,
      childId: _childId,
      chatNumber: chatNumber,
      level: mem.level,
      progressionModel: mode,
      turnsTotal: cur.turnCount,
      topic: cur.currentTopic?.topic,
      aimedAt: aimed,
      hitTargets: hitTargets,
      judgeScoresRaw: scoresJson,
      stateChanges: changesJson,
      transcriptRef: transcriptId,
      transcript: transcript,
    );
    final snap = MemorySnapshot(
      chat: chatNumber,
      model: mode,
      owned: List<String>.from(newMem.owned),
      emerging: List<String>.from(newMem.emerging),
      dueFlat: newMem.dueNext.flat,
    );
    final hist = HistoryEntry(
      chat: chatNumber,
      level: mem.level,
      model: mode,
      owned: newMem.owned.length,
      emerging: newMem.emerging.length,
      changes: effectiveChanges.length,
      turns: cur.turnCount,
      aimed: aimed.length,
      hit: hitTargets.length,
    );

    // Sys message — like the simulator's sys-line
    final String sysText;
    if (judgeFailed) {
      sysText = '⚠️ Judge unavailable — chat ended, no state changes.';
    } else {
      final grew = effectiveChanges.isEmpty
          ? 'No state changes'
          : 'Grew: ${effectiveChanges.map((c) => '${c.id} ${c.from}→${c.to}').join(', ')}';
      sysText = '$grew · aimed ${aimed.length}, hit ${hitTargets.length}';
    }
    final sysMsg = ChatMessage(sender: MessageSender.system, text: sysText);

    state = AsyncValue.data(
      cur.copyWith(
        memory: newMem,
        messages: [...cur.messages, sysMsg],
        status: ChatStatus.idle,
        lastChanges: effectiveChanges,
        sessionEnded: true,
        lastJudgeScores: primaryScores,
        lastJudgeScoresOther: otherScores,
        lastJudgeOtherLabel: mode,
        snapshots: [...cur.snapshots, snap],
        sessionLogs: [...cur.sessionLogs, inMemSession],
        historyEntries: [...cur.historyEntries, hist],
        aimedAt: aimed,
        hitTargets: hitTargets,
        liveLlmLastCall: liveLlm,
        lastSyncError: syncError,
        clearSyncError: syncError == null,
        clearActiveSessionId: true,
      ),
    );
  }

  // ── Next chat (keeps memory) ──────────────────────────────────────────────

  Future<void> nextChat({Topic? topicOverride}) async {
    final cur = state.requireValue;
    if (!cur.sessionEnded) return;

    final newDue = targetsListFor(
      cur.memory,
      cur.memory.progressionModel,
      cur.memory.level,
    );
    final carriedMem = cur.memory.copyWith(dueNext: newDue);

    state = AsyncValue.data(
      cur.copyWith(
        memory: carriedMem,
        messages: const [],
        turnCount: 0,
        sessionEnded: false,
        autoStep: 0,
        chatNumber: cur.chatNumber + 1,
        clearTopic: true,
        clearChanges: true,
        clearPartialStt: true,
        status: ChatStatus.idle,
      ),
    );
    await startSession(topicOverride: topicOverride);
  }

  // ── Abandon (discard an in-progress chat without scoring) ─────────────────

  /// Drops the current conversation without running the judge or touching
  /// memory — used when the child backs out of a session mid-chat. Clears the
  /// transcript and active session so the next topic starts a fresh session.
  Future<void> abandonSession() async {
    final cur = state.requireValue;
    if (cur.messages.isEmpty && !cur.sessionEnded) return; // nothing to abandon
    await stopSpeaking();
    await stopListening();
    state = AsyncValue.data(
      cur.copyWith(
        messages: const [],
        turnCount: 0,
        sessionEnded: false,
        autoStep: 0,
        clearTopic: true,
        clearActiveSessionId: true,
        clearChanges: true,
        clearPartialStt: true,
        status: ChatStatus.idle,
      ),
    );
  }

  // ── Reset (in-memory only — does NOT touch Supabase) ──────────────────────

  Future<void> resetAll() async {
    final cur = state.requireValue;
    final fresh = MemoryState.fresh(
      cur.memory.level,
      childId: _childId,
    ).copyWith(progressionModel: cur.memory.progressionModel);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, fresh.progressionModel, fresh.level),
    );
    state = AsyncValue.data(
      ChatState(
        memory: freshWithDue,
        inputMode: cur.inputMode,
        autoMode: cur.autoMode,
      ),
    );
    await startSession();
  }

  // ── Switch progression model (wipes in-memory state) ──────────────────────

  Future<void> setProgressionModel(String mode) async {
    final cur = state.requireValue;
    if (cur.memory.progressionModel == mode) return;
    final fresh = MemoryState.fresh(
      cur.memory.level,
      childId: _childId,
    ).copyWith(progressionModel: mode);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, mode, fresh.level),
    );
    state = AsyncValue.data(
      ChatState(
        memory: freshWithDue,
        inputMode: cur.inputMode,
        autoMode: cur.autoMode,
      ),
    );
    await startSession();
  }

  // ── Switch level (wipes in-memory state) ──────────────────────────────────

  Future<void> setLevel(String level) async {
    final cur = state.requireValue;
    if (cur.memory.level == level) return;
    final fresh = MemoryState.fresh(
      level,
      childId: _childId,
    ).copyWith(progressionModel: cur.memory.progressionModel);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, fresh.progressionModel, level),
    );
    state = AsyncValue.data(
      ChatState(
        memory: freshWithDue,
        inputMode: cur.inputMode,
        autoMode: cur.autoMode,
      ),
    );
    await startSession();
  }

  // ── Input mode + STT ──────────────────────────────────────────────────────

  void toggleInputMode() {
    final cur = state.requireValue;
    state = AsyncValue.data(
      cur.copyWith(
        inputMode: cur.inputMode == InputMode.voice
            ? InputMode.text
            : InputMode.voice,
      ),
    );
  }

  Future<void> startListening() async {
    final cur = state.requireValue;
    if (cur.sessionEnded) return;
    // Allow starting from idle OR while Zoe is speaking (interrupt her)
    if (cur.status == ChatStatus.zoeSpeaking) {
      await stopSpeaking();
    } else if (cur.status != ChatStatus.idle) {
      return;
    }
    state = AsyncValue.data(state.requireValue.copyWith(status: ChatStatus.userSpeaking));
    final stt = ref.read(sttProvider);
    await stt.startListening(
      onPartial: (partial) {
        if (state.hasValue) {
          state = AsyncValue.data(
            state.requireValue.copyWith(partialStt: partial),
          );
        }
      },
      onFinal: (text) {
        // Fired either by 4s-pause auto-stop OR by manual stopListening.
        if (!state.hasValue) return;
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          // Commit straight from userSpeaking → zoeThinking (sendUserTurn owns
          // the state update), so the caption never flashes Zoe's previous
          // line between the partial clearing and the turn landing.
          sendUserTurn(trimmed);
        } else {
          // Nothing recognised — just return to idle.
          state = AsyncValue.data(
            state.requireValue.copyWith(
              status: ChatStatus.idle,
              clearPartialStt: true,
            ),
          );
        }
      },
    );
  }

  /// Silence Zoe immediately, whatever TTS state she is in. Used when the child
  /// ends the chat mid-utterance so the session closes instantly.
  Future<void> stopSpeaking() async {
    try {
      await ref.read(ttsProvider).stop();
    } catch (_) {}
  }

  Future<void> stopListening() async {
    final stt = ref.read(sttProvider);
    await stt.stopListening();
    // After stop(), the plugin normally fires onResult(finalResult: true),
    // which onFinal commits. On platforms where that final is slow/missing
    // (Android SpeechRecognizer), this safety net kicks in: if we're still
    // stuck on userSpeaking, commit whatever partial we heard rather than
    // dropping to idle — going idle here would briefly flash Zoe's previous
    // line before the turn lands (the manual-stop bug).
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!state.hasValue) return;
      final s = state.requireValue;
      if (s.status != ChatStatus.userSpeaking) return; // onFinal handled it
      final partial = s.partialStt?.trim() ?? '';
      if (partial.isNotEmpty) {
        sendUserTurn(partial);
      } else {
        state = AsyncValue.data(
          s.copyWith(status: ChatStatus.idle, clearPartialStt: true),
        );
      }
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  // Choose the skill set the judge scores under for a given framing.
  // Matches the simulator's logic: in skill mode the unit-skills act as the
  // 'other' framing; in units mode the level's flat skills act as the 'other'.
  List<String> _idsForFraming(MemoryState mem, String mode) {
    if (mode == 'units') {
      final due = mem.dueNext.flat;
      if (due.isNotEmpty) return due;
      final freshDue = dueUnit(mem).picks.map((p) => p.id).toList();
      if (freshDue.isNotEmpty) return freshDue;
      final firstStep = kUnitSteps.isNotEmpty ? kUnitSteps.first : null;
      return firstStep == null
          ? const []
          : firstStep.skills.map((s) => s.id).toList();
    }
    // micro-skill framing
    final due = mem.dueNext.flat.where((id) => !id.startsWith('U')).toList();
    final fromEmerging = mem.emerging
        .where((id) => id.startsWith(mem.level))
        .toList();
    final ids = <String>{...due, ...fromEmerging}.toList();
    if (ids.isNotEmpty) return ids;
    return skillsAtLevel(mem.level).take(8).map((s) => s.id).toList();
  }

  Future<void> _zoeTurn(List<ConvMessage> history, Topic? topic) async {
    final cur = state.requireValue;
    String? lastUserText;
    for (final m in history) {
      if (m.role == 'user') lastUserText = m.text;
    }
    if (_online && cur.activeSessionId != null && lastUserText != null) {
      try {
        final api = ref.read(ellaApiServiceProvider);
        final turn = await api.conversationTurn(
          sessionId: cur.activeSessionId!,
          content: lastUserText,
        );
        final reply = turn.latestAssistantText;
        if (reply != null && reply.trim().isNotEmpty) {
          final zoeMsg = ChatMessage(
            sender: MessageSender.zoe,
            text: reply.trim(),
          );
          state = AsyncValue.data(
            state.requireValue.copyWith(
              messages: [...state.requireValue.messages, zoeMsg],
              status: ChatStatus.zoeSpeaking,
              liveLlmLastCall: true,
            ),
          );
          try {
            final tts = ref.read(ttsProvider);
            await tts.speak(zoeMsg.text);
          } catch (_) {}
          if (state.hasValue) {
            state = AsyncValue.data(
              state.requireValue.copyWith(status: ChatStatus.idle),
            );
          }
          // Auto-end chat if conversation is complete
          if (turn.conversationComplete) {
            await endChat();
          }
          return;
        }
      } catch (e) {
        state = AsyncValue.data(
          cur.copyWith(lastSyncError: 'Conversation turn API failed: $e'),
        );
      }
    }

    final prompts = ref.read(promptsOverrideProvider);
    final prompt = buildConvPrompt(
      mem: cur.memory,
      progressionModel: cur.memory.progressionModel,
      level: cur.memory.level,
      history: history,
      prompts: prompts,
      currentTopic: topic,
    );

    String zoeText;
    bool live;
    try {
      final llm = ref.read(llmServiceProvider);
      zoeText = await llm.conv(prompt);
      live = true;
    } catch (_) {
      // Fallback so conversation never gets stuck. User can still send turns.
      zoeText = "Hmm, I'm having a moment. What were you saying?";
      live = false;
    }

    final zoeMsg = ChatMessage(sender: MessageSender.zoe, text: zoeText);
    state = AsyncValue.data(
      state.requireValue.copyWith(
        messages: [...state.requireValue.messages, zoeMsg],
        status: ChatStatus.zoeSpeaking,
        liveLlmLastCall: live,
      ),
    );

    try {
      final tts = ref.read(ttsProvider);
      await tts.speak(zoeText);
    } catch (_) {
      // TTS failure is non-fatal — message is on screen already.
    }

    if (state.hasValue) {
      state = AsyncValue.data(
        state.requireValue.copyWith(status: ChatStatus.idle),
      );
    }
  }
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
