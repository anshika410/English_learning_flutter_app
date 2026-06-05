// Chat orchestration — the single in-memory store for the simulator's reactive model.
//
// ChatNotifier loads MemoryState from Supabase (or fresh if not found),
// manages the conversation loop, accumulates snapshots/sessions/history,
// runs dual judging at endChat, and supports auto mode + mode/level/reset.
//
// Non-negotiable: only applyMerge / applyEndChat write owned/emerging/due_next.
// The LLM result (SkillScore list) is passed to the engine, never written directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/engine.dart';
import '../core/skill_data.dart';
import '../core/topic_data.dart';
import '../models/child_memory.dart';
import '../models/history_entry.dart';
import '../models/memory_snapshot.dart';
import '../models/message.dart';
import '../models/session.dart';
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
  final int chatNumber; // 1-based; resets only on resetAll/setLevel/setProgressionModel
  final bool autoMode;
  final int autoStep; // number of auto turns taken so far
  final List<SkillScore> lastJudgeScores; // primary framing
  final List<SkillScore> lastJudgeScoresOther; // alternate framing
  final String lastJudgeOtherLabel; // 'units' | 'micro-skill' (empty if no judge yet)
  final List<MemorySnapshot> snapshots;
  final List<SessionLog> sessionLogs;
  final List<HistoryEntry> historyEntries;
  final List<String> aimedAt;
  final List<String> hitTargets;
  final bool liveLlmLastCall;

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
    String? lastSyncError,
    bool clearSyncError = false,
  }) =>
      ChatState(
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
        lastSyncError:
            clearSyncError ? null : (lastSyncError ?? this.lastSyncError),
      );

  List<ConvMessage> get convHistory => messages
      .where((m) => m.sender != MessageSender.system)
      .map((m) => ConvMessage(
            role: m.sender == MessageSender.zoe ? 'zoe' : 'user',
            text: m.text,
          ))
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

    final supabaseClient = Supabase.instance.client;
    final svc = ref.read(supabaseServiceProvider);

    String? syncError;
    MemoryState mem;
    List<SessionLog> sessions = const [];
    List<HistoryEntry> history = const [];
    int nextChatNumber = 1;

    try {
      // Anonymous sign-in — gives us an auth.uid() that the _TEST_ RLS
      // policies can match against. Cached by supabase_flutter across
      // app restarts via secure storage.
      // NOTE: requires the "Anonymous Sign-Ins" provider to be enabled in
      // Supabase → Authentication → Sign In / Up. If it's off, this throws
      // AuthApiException(code: anonymous_provider_disabled) and we fall back
      // to offline-only mode below.
      if (supabaseClient.auth.currentUser == null) {
        await supabaseClient.auth.signInAnonymously();
      }
      _childId = supabaseClient.auth.currentUser!.id;

      // Make sure a `children` row exists for this uid (FK source).
      await svc.ensureChild(childId: _childId);

      // Resume memory from persisted state if any, else fresh.
      mem = await svc.fetchMemory(_childId) ??
          MemoryState.fresh('A1', childId: _childId);
      nextChatNumber = mem.chatCount > 0 ? mem.chatCount + 1 : 1;
      _online = true;

      // Restore Session/History tabs from the last 20 chats. Best-effort:
      // a failure here doesn't break memory restoration.
      try {
        final fetched =
            await svc.fetchRecentSessions(childId: _childId, limit: 20);
        // Order ascending by chat_number for the UI lists (oldest first).
        sessions =
            [...fetched]..sort((a, b) => a.chatNumber.compareTo(b.chatNumber));
        history = sessions
            .map((s) => HistoryEntry(
                  chat: s.chatNumber,
                  level: s.level,
                  model: s.progressionModel,
                  owned: 0, // not stored per-chat
                  emerging: 0, // not stored per-chat
                  changes: s.stateChanges.length,
                  turns: s.turnsTotal,
                  aimed: s.aimedAt.length,
                  hit: s.hitTargets.length,
                ))
            .toList();
        if (sessions.isNotEmpty) {
          final maxChat = sessions
              .map((s) => s.chatNumber)
              .fold<int>(0, (a, b) => a > b ? a : b);
          if (maxChat + 1 > nextChatNumber) nextChatNumber = maxChat + 1;
        }
      } catch (e) {
        syncError = 'Session history restore failed: $e';
      }
    } catch (e) {
      // Offline-only mode. App still works in memory; Glass Box shows the error.
      // No Supabase writes will be attempted while _online is false.
      _online = false;
      _childId = _kOfflineChildId;
      mem = MemoryState.fresh('A1', childId: _childId);
      syncError = 'Supabase init failed: $e';
    }

    return ChatState(
      memory: mem,
      sessionLogs: sessions,
      historyEntries: history,
      chatNumber: nextChatNumber,
      lastSyncError: syncError,
    );
  }

  // ── Session start ────────────────────────────────────────────────────────

  Future<void> startSession() async {
    final cur = state.requireValue;
    if (cur.sessionEnded || cur.messages.isNotEmpty) return;

    final topic = pickTopic(cur.memory);
    state = AsyncValue.data(cur.copyWith(
      status: ChatStatus.zoeThinking,
      currentTopic: topic,
    ));

    await _zoeTurn([], topic);
  }

  // ── User turn ─────────────────────────────────────────────────────────────

  Future<void> sendUserTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final cur = state.requireValue;
    if (cur.sessionEnded || cur.status != ChatStatus.idle) return;

    final userMsg = ChatMessage(sender: MessageSender.child, text: trimmed);
    final msgs = [...cur.messages, userMsg];

    state = AsyncValue.data(cur.copyWith(
      messages: msgs,
      status: ChatStatus.zoeThinking,
      turnCount: cur.turnCount + 1,
      clearPartialStt: true,
    ));

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
    state = AsyncValue.data(cur.copyWith(
      status: ChatStatus.zoeThinking,
      autoStep: cur.autoStep + 1,
    ));
    try {
      final llm = ref.read(llmServiceProvider);
      final reply = await llm.mockLearner(
        history: cur.convHistory,
        level: cur.memory.level,
      );
      state = AsyncValue.data(state.requireValue.copyWith(
        status: ChatStatus.idle,
        liveLlmLastCall: true,
      ));
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
      state = AsyncValue.data(state.requireValue.copyWith(
        status: ChatStatus.idle,
        liveLlmLastCall: false,
      ));
      await sendUserTurn(reply);
    }
  }

  // ── End chat + DUAL judge ─────────────────────────────────────────────────

  Future<void> endChat() async {
    final cur = state.requireValue;
    if (cur.sessionEnded || cur.messages.isEmpty) return;

    state = AsyncValue.data(cur.copyWith(status: ChatStatus.zoeThinking));

    final llm = ref.read(llmServiceProvider);
    final prompts = ref.read(promptsOverrideProvider);
    final mem = cur.memory;
    final mode = mem.progressionModel;

    // Build both judge prompts
    final primaryIds = _idsForFraming(mem, mode);
    final primaryPrompt = buildJudgePrompt(
      level: mem.level,
      skillIds: primaryIds,
      history: cur.convHistory,
      prompts: prompts,
    );
    final otherMode = mode == 'units' ? 'micro-skill' : 'units';
    final otherIds = _idsForFraming(mem, otherMode);
    final otherPrompt = buildJudgePrompt(
      level: mem.level,
      skillIds: otherIds,
      history: cur.convHistory,
      prompts: prompts,
    );

    // Run both in parallel. Each catches its own error and returns [] so the
    // user can ALWAYS reach sessionEnded=true and move on to the next chat.
    final primaryFuture =
        llm.judge(primaryPrompt).catchError((Object _) => <SkillScore>[]);
    final otherFuture =
        llm.judge(otherPrompt).catchError((Object _) => <SkillScore>[]);
    final results = await Future.wait([primaryFuture, otherFuture]);
    final primaryScores = results[0];
    final otherScores = results[1];
    final judgeFailed = primaryScores.isEmpty;
    final liveLlm = !judgeFailed;

    // Aim/hit
    final aimed = mem.dueNext.flat;
    final hitTargets = aimed
        .where((id) => primaryScores
            .any((s) => s.id == id && s.confidence >= kFloor))
        .toList();

    // Deterministic merge — LLM never writes state.
    // If primary failed, scores is empty so no state changes; user can still move on.
    final mergeResult = applyMerge(mem, primaryScores, mem.level);
    final chatNumber = cur.chatNumber;
    final newMem = applyEndChat(
      mem: mem,
      mergeResult: mergeResult,
      turnCount: cur.turnCount,
      chatNumber: chatNumber,
      usedTopic: cur.currentTopic,
      progressionModel: mode,
      level: mem.level,
    ).copyWith(chatCount: mem.chatCount + 1);

    // Build the transcript as {speaker,text} maps — kept in memory for the
    // Session tab JSON, and also sent to the `transcripts` table.
    final transcript = cur.messages
        .where((m) => m.sender != MessageSender.system)
        .map((m) => {
              'speaker':
                  m.sender == MessageSender.zoe ? 'zoe' : 'learner',
              'text': m.text,
            })
        .toList();

    final scoresJson = primaryScores.map((s) => s.toJson()).toList();
    final changesJson = mergeResult.changes
        .map((c) => {'id': c.id, 'from': c.from, 'to': c.to})
        .toList();

    // Persist to Supabase — only when we successfully signed in at startup.
    // Offline mode (e.g. anonymous sign-ins disabled in the project) keeps
    // the chat working in memory without spamming failed requests.
    String? transcriptId;
    String? sessionId;
    String? syncError;
    if (_online) {
      try {
        final supabase = ref.read(supabaseServiceProvider);
        transcriptId = await supabase.insertTranscript(
          childId: _childId,
          turns: transcript,
        );
        final dbSession = SessionLog(
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
        );
        sessionId = await supabase.insertSession(dbSession);
        await supabase.upsertMemory(newMem);
      } catch (e) {
        syncError = 'Supabase persist failed: $e';
      }
    } else {
      syncError =
          'Offline mode — Supabase writes skipped (anon sign-in disabled?).';
    }

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
      changes: mergeResult.changes.length,
      turns: cur.turnCount,
      aimed: aimed.length,
      hit: hitTargets.length,
    );

    // Sys message — like the simulator's sys-line
    final String sysText;
    if (judgeFailed) {
      sysText = '⚠️ Judge unavailable — chat ended, no state changes.';
    } else {
      final grew = mergeResult.changes.isEmpty
          ? 'No state changes'
          : 'Grew: ${mergeResult.changes.map((c) => '${c.id} ${c.from}→${c.to}').join(', ')}';
      sysText = '$grew · aimed ${aimed.length}, hit ${hitTargets.length}';
    }
    final sysMsg =
        ChatMessage(sender: MessageSender.system, text: sysText);

    state = AsyncValue.data(cur.copyWith(
      memory: newMem,
      messages: [...cur.messages, sysMsg],
      status: ChatStatus.idle,
      lastChanges: mergeResult.changes,
      sessionEnded: true,
      lastJudgeScores: primaryScores,
      lastJudgeScoresOther: otherScores,
      lastJudgeOtherLabel: otherMode,
      snapshots: [...cur.snapshots, snap],
      sessionLogs: [...cur.sessionLogs, inMemSession],
      historyEntries: [...cur.historyEntries, hist],
      aimedAt: aimed,
      hitTargets: hitTargets,
      liveLlmLastCall: liveLlm,
      lastSyncError: syncError,
      clearSyncError: syncError == null,
    ));
  }

  // ── Next chat (keeps memory) ──────────────────────────────────────────────

  Future<void> nextChat() async {
    final cur = state.requireValue;
    if (!cur.sessionEnded) return;

    final newDue = targetsListFor(
      cur.memory,
      cur.memory.progressionModel,
      cur.memory.level,
    );
    final carriedMem = cur.memory.copyWith(dueNext: newDue);

    state = AsyncValue.data(cur.copyWith(
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
    ));
    await startSession();
  }

  // ── Reset (in-memory only — does NOT touch Supabase) ──────────────────────

  Future<void> resetAll() async {
    final cur = state.requireValue;
    final fresh = MemoryState.fresh(cur.memory.level, childId: _childId)
        .copyWith(progressionModel: cur.memory.progressionModel);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, fresh.progressionModel, fresh.level),
    );
    state = AsyncValue.data(ChatState(
      memory: freshWithDue,
      inputMode: cur.inputMode,
      autoMode: cur.autoMode,
    ));
    await startSession();
  }

  // ── Switch progression model (wipes in-memory state) ──────────────────────

  Future<void> setProgressionModel(String mode) async {
    final cur = state.requireValue;
    if (cur.memory.progressionModel == mode) return;
    final fresh = MemoryState.fresh(cur.memory.level, childId: _childId)
        .copyWith(progressionModel: mode);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, mode, fresh.level),
    );
    state = AsyncValue.data(ChatState(
      memory: freshWithDue,
      inputMode: cur.inputMode,
      autoMode: cur.autoMode,
    ));
    await startSession();
  }

  // ── Switch level (wipes in-memory state) ──────────────────────────────────

  Future<void> setLevel(String level) async {
    final cur = state.requireValue;
    if (cur.memory.level == level) return;
    final fresh = MemoryState.fresh(level, childId: _childId)
        .copyWith(progressionModel: cur.memory.progressionModel);
    final freshWithDue = fresh.copyWith(
      dueNext: targetsListFor(fresh, fresh.progressionModel, level),
    );
    state = AsyncValue.data(ChatState(
      memory: freshWithDue,
      inputMode: cur.inputMode,
      autoMode: cur.autoMode,
    ));
    await startSession();
  }

  // ── Input mode + STT ──────────────────────────────────────────────────────

  void toggleInputMode() {
    final cur = state.requireValue;
    state = AsyncValue.data(cur.copyWith(
      inputMode:
          cur.inputMode == InputMode.voice ? InputMode.text : InputMode.voice,
    ));
  }

  Future<void> startListening() async {
    final cur = state.requireValue;
    if (cur.status != ChatStatus.idle || cur.sessionEnded) return;
    state = AsyncValue.data(cur.copyWith(status: ChatStatus.userSpeaking));
    final stt = ref.read(sttProvider);
    await stt.startListening(
      onPartial: (partial) {
        if (state.hasValue) {
          state = AsyncValue.data(
              state.requireValue.copyWith(partialStt: partial));
        }
      },
      onFinal: (text) {
        // Fired either by 4s-pause auto-stop OR by manual stopListening.
        if (!state.hasValue) return;
        // Flip status to idle so sendUserTurn proceeds.
        state = AsyncValue.data(state.requireValue.copyWith(
          status: ChatStatus.idle,
          clearPartialStt: true,
        ));
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          // Fire-and-forget — sendUserTurn handles its own state updates.
          sendUserTurn(trimmed);
        }
      },
    );
  }

  Future<void> stopListening() async {
    final stt = ref.read(sttProvider);
    await stt.stopListening();
    // After stop(), the plugin fires onResult(finalResult: true) which our
    // onFinal handler picks up. As a safety net, flip status idle if it's
    // still stuck on userSpeaking after a short delay.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (state.hasValue &&
          state.requireValue.status == ChatStatus.userSpeaking) {
        state = AsyncValue.data(state.requireValue
            .copyWith(status: ChatStatus.idle, clearPartialStt: true));
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
      final firstStep = kUnitSteps.isNotEmpty ? kUnitSteps.first : null;
      return firstStep == null
          ? const []
          : firstStep.skills.map((s) => s.id).toList();
    }
    // micro-skill framing
    final due = mem.dueNext.flat.where((id) => !id.startsWith('U')).toList();
    final fromEmerging = mem.emerging.where((id) => id.startsWith(mem.level)).toList();
    final ids = <String>{...due, ...fromEmerging}.toList();
    if (ids.isNotEmpty) return ids;
    return skillsAtLevel(mem.level).take(8).map((s) => s.id).toList();
  }

  Future<void> _zoeTurn(List<ConvMessage> history, Topic? topic) async {
    final cur = state.requireValue;
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
    state = AsyncValue.data(state.requireValue.copyWith(
      messages: [...state.requireValue.messages, zoeMsg],
      status: ChatStatus.zoeSpeaking,
      liveLlmLastCall: live,
    ));

    try {
      final tts = ref.read(ttsProvider);
      await tts.speak(zoeText);
    } catch (_) {
      // TTS failure is non-fatal — message is on screen already.
    }

    if (state.hasValue) {
      state = AsyncValue.data(
          state.requireValue.copyWith(status: ChatStatus.idle));
    }
  }

}

final chatProvider =
    AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
