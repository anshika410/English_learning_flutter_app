// Chat orchestration — the single in-memory store for the conversation state.
//
// ChatNotifier loads MemoryState from the Ella API (or fresh if not found),
// manages the conversation loop, and closes sessions via the server judge.
//
// Non-negotiable: only applyMerge / applyEndChat write owned/emerging/due_next.
// The judge result (SkillScore list) is passed to the engine, never written directly.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/engine.dart';
import '../core/topic_data.dart';
import '../models/child_memory.dart';
import '../models/message.dart';
import '../services/analytics_service.dart';
import '../services/ella_api_service.dart';
import 'dart:io';
import 'garden_provider.dart';
import 'onboarding_provider.dart';
import 'connectivity_provider.dart';
import 'service_providers.dart';
import '../services/sounds.dart';

enum InputMode { voice, text }

enum ChatStatus { idle, zoeThinking, zoeSpeaking, userSpeaking, offline, speechError }

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
  final String? currentlySpeakingMessageId;
  final int highlightStart;
  final int highlightEnd;

  final int
  chatNumber; // 1-based; resets only on resetAll/setLevel/setProgressionModel
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
    this.currentlySpeakingMessageId,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.chatNumber = 1,
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
    List<String>? aimedAt,
    List<String>? hitTargets,
    bool? liveLlmLastCall,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    List<String>? serverAimedAt,
    String? lastSyncError,
    bool clearSyncError = false,
    String? currentlySpeakingMessageId,
    bool clearCurrentlySpeaking = false,
    int? highlightStart,
    int? highlightEnd,
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
    currentlySpeakingMessageId: clearCurrentlySpeaking
        ? null
        : (currentlySpeakingMessageId ?? this.currentlySpeakingMessageId),
    highlightStart: highlightStart ?? this.highlightStart,
    highlightEnd: highlightEnd ?? this.highlightEnd,
    chatNumber: chatNumber ?? this.chatNumber,
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

class ChatNotifier extends AsyncNotifier<ChatState> with WidgetsBindingObserver {
  // Resolved at build() time. Equals the Supabase auth uid when sign-in
  // succeeds; equals _kOfflineChildId otherwise.
  late String _childId;
  // true when auth+ensureChild succeeded — gates Supabase writes in endChat.
  bool _online = false;
  int _activeSttSessionId = 0;
  bool _sttSessionFinalized = false;

  /// Tracks when the current session started (for P0 conversation_ended).
  DateTime? _sessionStartedAt;

  String get childId => _childId;
  bool get online => _online;
  DateTime? get sessionStartedAt => _sessionStartedAt;

  @override
  Future<ChatState> build() async {
    // Register app lifecycle observer to stop recording when app goes to background
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });

    // Init TTS eagerly (no permission needed). STT initialize() triggers the OS
    // mic-permission prompt, so it is deferred to the first listen (see
    // startListening) to avoid blocking screen load / prompting at launch.
    final tts = ref.read(ttsProvider);
    try {
      await tts.initialize();
    } catch (e) {
      print('⚠️ TTS initialization failed: $e');
    }

    // Listen to network changes so we can recover from offline mode
    ref.listen(connectivityProvider, (previous, next) {
      final isOnline = next.valueOrNull ?? true;
      if (isOnline != _online) {
        _online = isOnline;
        if (isOnline) {
          final cur = state.valueOrNull;
          if (cur != null && cur.status == ChatStatus.offline) {
            state = AsyncValue.data(cur.copyWith(status: ChatStatus.zoeThinking));
            _zoeTurn(cur.convHistory, cur.currentTopic);
          } else if (cur == null || cur.messages.isEmpty) {
            ref.invalidateSelf();
          }
        } else {
          // Went offline
          final cur = state.valueOrNull;
          if (cur != null) {
            state = AsyncValue.data(cur.copyWith(status: ChatStatus.offline));
          }
        }
      }
    });
    // STT is NOT initialized here to avoid triggering the mic permission prompt
    // during screen load. It will be lazily initialized on first voice use in
    // startListening() method.

    // Register TTS range callbacks to drive Karaoke text highlighting
    final activeTts = ref.read(ttsProvider);
    final progressSub = activeTts.progressStream.listen((event) {
      if (state.hasValue) {
        state = AsyncValue.data(
          state.requireValue.copyWith(
            highlightStart: event.start,
            highlightEnd: event.end,
          ),
        );
      }
    });
    final doneSub = activeTts.doneStream.listen((_) {
      if (state.hasValue) {
        final cur = state.requireValue;
        final wasSpeaking = cur.currentlySpeakingMessageId != null;
        state = AsyncValue.data(
          cur.copyWith(
            status: cur.status == ChatStatus.zoeSpeaking ? ChatStatus.idle : cur.status,
            clearCurrentlySpeaking: true,
            highlightStart: -1,
            highlightEnd: -1,
          ),
        );
        if (wasSpeaking && !cur.sessionEnded) {
          ref.read(audioProvider).playSfx(Sounds.turn);
        }
      }
    });
    ref.onDispose(() {
      progressSub.cancel();
      doneSub.cancel();
    });

    final api = ref.read(ellaApiServiceProvider);

    String? syncError;
    MemoryState mem;
    int nextChatNumber = 1;

    try {
      _childId = await api.getCachedUserId() ?? _kOfflineChildId;

      // Make sure a `children` row exists for this uid (FK source).
      // User creation is handled by POST /auth/google or magic link.

      // Canonical load order: auth → memory → garden (mirrors the server flow).
      // Resume memory from persisted state if any, else fresh.
      mem = await api.getUserMemory();
      if (mem.name != null && mem.name!.trim().isNotEmpty) {
        try {
          await ref
              .read(onboardingProvider.notifier)
              .seedFromServer(name: mem.name!, age: mem.age);
        } catch (_) {}
      }
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
      if (e is EllaApiException && e.message == 'not_authenticated') {
        rethrow;
      }
      // Offline-only mode. App still works in memory; Glass Box shows the error.
      // No Supabase writes will be attempted while _online is false.
      _online = false;
      _childId = _kOfflineChildId;
      mem = MemoryState.fresh('A1', childId: _childId);
      syncError = 'Ella API init failed: $e';
    }

    return ChatState(
      memory: mem,
      chatNumber: nextChatNumber,
      lastSyncError: syncError,
    );
  }

  // ── App Lifecycle Observer ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App going to background - stop recording immediately if active
        if (state.hasValue) {
          final cur = state.requireValue;
          if (cur.status == ChatStatus.userSpeaking) {
            // Stop the microphone and finalize whatever was captured
            stopListening();
            
            // Update state to idle with clear message
            if (state.hasValue) {
              state = AsyncValue.data(
                state.requireValue.copyWith(
                  status: ChatStatus.idle,
                  clearPartialStt: true,
                ),
              );
            }
          }
        }
        break;
      case AppLifecycleState.resumed:
        // App back in foreground - no action needed
        // User must tap the mic button again to start recording
        break;
    }
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

    ref.read(audioProvider).playSfx(Sounds.start);
    _sessionStartedAt = DateTime.now();

    // A tapped home-screen topic overrides the engine's pick; otherwise the
    // engine chooses the next topic as before.
    final topic = topicOverride ?? pickTopic(cur.memory);
    String? backendSessionId;
    String? starter;
    List<String> serverAimedAt = const [];
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
        state = AsyncValue.error(e, StackTrace.current);
        return;
      }
    } else {
      state = AsyncValue.error(
        const EllaApiException('network_error'),
        StackTrace.current,
      );
      return;
    }

    if (starter == null || starter.trim().isEmpty) {
      state = AsyncValue.error(
        const EllaApiException('empty_starter_message'),
        StackTrace.current,
      );
      return;
    }

    state = AsyncValue.data(
      cur.copyWith(
        status: ChatStatus.zoeThinking,
        currentTopic: topic,
        activeSessionId: backendSessionId,
        serverAimedAt: serverAimedAt,
        clearSyncError: true,
      ),
    );

    try {
      final tName = topic?.topic ?? 'Free Talk';
      AnalyticsService.logTopicStarted(tName);
      for (final skill in serverAimedAt) {
        AnalyticsService.logSkillAttempted(skill);
      }

      // P0 enriched conversation_started
      final topicSource = cur.currentTopic != null ? 'user_selected' : 'engine';
      final primarySkill =
          serverAimedAt.isNotEmpty ? serverAimedAt.first : null;
      AnalyticsService.logConversationStartedP0(
        userId: _childId ?? '',
        sessionId: backendSessionId ?? '',
        topicId: tName,
        topicSource: topicSource,
        levelAtStart: cur.memory.level,
        primarySkillId: primarySkill,
        conversationIndex: cur.chatNumber,
      );
    } catch (_) {}

    final zoeMsg = ChatMessage(
      sender: MessageSender.zoe,
      text: starter.trim(),
    );
    // Set state to zoeSpeaking but do NOT call tts.speak() here.
    // The session screen owns TTS for the starter — it will speak once mounted.
    state = AsyncValue.data(
      state.requireValue.copyWith(
        messages: [zoeMsg],
        status: ChatStatus.zoeSpeaking,
        liveLlmLastCall: true,
        currentlySpeakingMessageId: zoeMsg.id,
        highlightStart: -1,
        highlightEnd: -1,
      ),
    );
    return;
  }

  // ── User turn ─────────────────────────────────────────────────────────────

  /// Called by SessionScreen after it has spoken the starter message that
  /// startSession queued. Resets status from zoeSpeaking → idle.
  void markStarterSpoken() {
    final cur = state.valueOrNull;
    if (cur != null && cur.status == ChatStatus.zoeSpeaking) {
      state = AsyncValue.data(cur.copyWith(
        status: ChatStatus.idle,
        clearCurrentlySpeaking: true,
      ));
    }
  }

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
        cur.status != ChatStatus.userSpeaking &&
        cur.status != ChatStatus.speechError) {
      return;
    }

    ref.read(audioProvider).playSfx(Sounds.send);

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

  // ── End chat (server judge) ───────────────────────────────────────────────

  Future<void> endChat() async {
    final cur = state.requireValue;
    if (cur.sessionEnded || cur.messages.isEmpty) return;

    ref.read(audioProvider).playSfx(Sounds.complete);

    final mem = cur.memory;
    final mode = mem.progressionModel;
    final chatNumber = cur.chatNumber;
    final initialTargets = cur.serverAimedAt.isNotEmpty
        ? cur.serverAimedAt
        : mem.dueNext.flat;
    ref.read(gardenGrowthRevealProvider.notifier).clear();
    ref
        .read(postConversationGardenRevealProvider.notifier)
        .begin(
          chatNumber: chatNumber,
          turnCount: cur.turnCount,
          targetSkillIds: initialTargets,
          before: mem,
        );
    ref.read(selectedGardenLevelProvider.notifier).state = null;

    state = AsyncValue.data(
      cur.copyWith(
        status: ChatStatus.zoeThinking,
        sessionEnded: true,
      ),
    );

    String? syncError;
    List<SkillScore> primaryScores = const [];
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

        // The garden provider is invalidated after the reveal result resolves,
        // so fetching it here would duplicate the same request and delay the
        // handoff. The canonical session log is useful for diagnostics but is
        // not needed to decide the reveal, so keep it off the critical path.
        final completedSessionId = cur.activeSessionId!;
        unawaited(() async {
          try {
            await api.getSessionLog(completedSessionId);
          } catch (_) {}
        }());
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
      // ── Offline fallback: deterministic engine merge with no judge scores.
      // The session still closes cleanly; no state changes are invented.
      final merge = applyMerge(mem, primaryScores, mem.level);
      effectiveChanges = merge.changes;
      aimed = mem.dueNext.flat;
      hitTargets = const [];
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

    final revealTargets = <String>{
      ...aimed,
      ...cur.serverAimedAt,
      ...newMem.dueNext.flat,
    }.toList(growable: false);
    ref
        .read(postConversationGardenRevealProvider.notifier)
        .resolve(
          chatNumber: chatNumber,
          turnCount: cur.turnCount,
          targetSkillIds: revealTargets,
          before: mem,
          after: newMem,
          sessionScores: primaryScores,
        );
    // Resolve the retained outcome before refreshing. A mounted garden will
    // keep its preparing overlay up until this fresh payload is processed; a
    // newly mounted garden will fetch the same canonical post-session data.
    ref.invalidate(gardenProvider);

    final judgeFailed = primaryScores.isEmpty;

    // Sys message — summarises how the session closed
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

    try {
      final topicName = cur.currentTopic?.topic ?? 'Free Talk';
      await AnalyticsService.logTopicCompleted(topicName);

      await AnalyticsService.logConversationComplete(
        topic: topicName,
        messageCount: cur.turnCount,
        durationSeconds: 0,
        level: mem.level,
        progressionModel: mode,
      );

      if (newMem.level != mem.level) {
        await AnalyticsService.logCefrLevelAssigned(newMem.level);
        await AnalyticsService.logGardenCompleted(mem.level);
      }

      for (final c in effectiveChanges) {
        if (c.to == 'owned' || c.to == 'emerging') {
          final parts = c.id.split('-');
          final strand = parts.length >= 2 ? parts[1] : 'unknown';
          await AnalyticsService.logSkillGained(
            skillId: c.id,
            strand: strand,
            toState: c.to,
          );
        }
      }

      // P0 enriched conversation_ended
      final sessionEndedAt = DateTime.now();
      await AnalyticsService.logConversationEnded(
        userId: _childId,
        sessionId: cur.activeSessionId ?? '',
        endState: 'auto_complete',
        studentTurns: cur.turnCount,
        startedAt: _sessionStartedAt ?? sessionEndedAt,
        endedAt: sessionEndedAt,
      );
    } catch (_) {}

    state = AsyncValue.data(
      cur.copyWith(
        memory: newMem,
        messages: [...cur.messages, sysMsg],
        status: ChatStatus.idle,
        lastChanges: effectiveChanges,
        sessionEnded: true,
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

  /// Clears a completed session while preserving its refreshed memory.
  ///
  /// This synchronous half of [nextChat] lets a destination screen mount before
  /// starting its API call, which is important for shared-element transitions.
  void prepareNextChat() {
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
        chatNumber: cur.chatNumber + 1,
        clearTopic: true,
        clearChanges: true,
        clearPartialStt: true,
        status: ChatStatus.idle,
      ),
    );
  }

  Future<void> nextChat({Topic? topicOverride}) async {
    final cur = state.requireValue;
    if (!cur.sessionEnded) return;
    prepareNextChat();
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
    } else if (cur.status != ChatStatus.idle && cur.status != ChatStatus.speechError) {
      return;
    }

    _sttSessionFinalized = false;
    final sessionId = ++_activeSttSessionId;

    state = AsyncValue.data(
      state.requireValue.copyWith(status: ChatStatus.userSpeaking),
    );
    ref.read(audioProvider).playSfx(Sounds.listen);
    final stt = ref.read(sttProvider);
    // Lazily init STT (idempotent) so the mic-permission prompt appears now, on
    // first voice use, rather than at app launch.
    await stt.initialize();
    await stt.startListening(
      onPartial: (partial) {
        if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
        if (state.hasValue) {
          state = AsyncValue.data(
            state.requireValue.copyWith(partialStt: partial),
          );
        }
      },
      onFinal: (text) {
        // Fired either by 4s-pause auto-stop OR by manual stopListening.
        if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
        _sttSessionFinalized = true;

        if (!state.hasValue) return;
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          // Commit straight from userSpeaking → zoeThinking (sendUserTurn owns
          // the state update), so the caption never flashes Zoe's previous
          // line between the partial clearing and the turn landing.
          sendUserTurn(trimmed);
        } else {
          // Nothing recognised — transition to speechError so UI shows Try Again.
          state = AsyncValue.data(
            state.requireValue.copyWith(
              status: ChatStatus.speechError,
              clearPartialStt: true,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (state.hasValue && state.requireValue.status == ChatStatus.speechError) {
              state = AsyncValue.data(
                state.requireValue.copyWith(status: ChatStatus.idle),
              );
            }
          });
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
    if (state.hasValue) {
      state = AsyncValue.data(
        state.requireValue.copyWith(
          status: ChatStatus.idle,
          clearCurrentlySpeaking: true,
          highlightStart: -1,
          highlightEnd: -1,
        ),
      );
    }
  }

  Future<void> stopListening() async {
    final stt = ref.read(sttProvider);
    await stt.stopListening();

    final sessionId = _activeSttSessionId;

    // After stop(), the plugin normally fires onResult(finalResult: true),
    // which onFinal commits. On platforms where that final is slow/missing
    // (Android SpeechRecognizer), this safety net kicks in: if we're still
    // stuck on userSpeaking, commit whatever partial we heard rather than
    // dropping to idle — going idle here would briefly flash Zoe's previous
    // line before the turn lands (the manual-stop bug).
    Future.delayed(const Duration(milliseconds: 400), () {
      if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
      _sttSessionFinalized = true;

      if (!state.hasValue) return;
      final s = state.requireValue;
      if (s.status != ChatStatus.userSpeaking) return; // onFinal handled it
      final partial = s.partialStt?.trim() ?? '';
      if (partial.isNotEmpty) {
        sendUserTurn(partial);
      } else {
        state = AsyncValue.data(
          s.copyWith(status: ChatStatus.speechError, clearPartialStt: true),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (state.hasValue && state.requireValue.status == ChatStatus.speechError) {
            state = AsyncValue.data(
              state.requireValue.copyWith(status: ChatStatus.idle),
            );
          }
        });
      }
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────

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
          inputMode: cur.inputMode == InputMode.voice ? 'voice' : 'text',
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
              currentlySpeakingMessageId: zoeMsg.id,
              highlightStart: -1,
              highlightEnd: -1,
            ),
          );
          try {
            final tts = ref.read(ttsProvider);
            await tts.speak(zoeMsg.text);
          } catch (_) {}
          if (state.hasValue && state.requireValue.status == ChatStatus.zoeSpeaking) {
            state = AsyncValue.data(
              state.requireValue.copyWith(
                status: ChatStatus.idle,
                clearCurrentlySpeaking: true,
              ),
            );
          }
          // Auto-end chat if conversation is complete
          if (turn.conversationComplete) {
            unawaited(endChat());
          }
          return;
        }
      } catch (e) {
        if (e is SocketException || e.toString().contains('network') || e.toString().contains('SocketException')) {
          state = AsyncValue.data(cur.copyWith(status: ChatStatus.offline));
          return;
        }
        state = AsyncValue.data(
          cur.copyWith(lastSyncError: 'Conversation turn API failed: $e'),
        );
      }
    }

    // No backend reply (offline, no active session, or the turn API failed).
    if (!_online) {
      state = AsyncValue.data(
        state.requireValue.copyWith(status: ChatStatus.offline),
      );
      return;
    }

    // Canned line so the conversation never gets stuck; the child can retry.
    const zoeText = "Hmm, I'm having a moment. What were you saying?";

    final zoeMsg = ChatMessage(sender: MessageSender.zoe, text: zoeText);
    state = AsyncValue.data(
      state.requireValue.copyWith(
        messages: [...state.requireValue.messages, zoeMsg],
        status: ChatStatus.zoeSpeaking,
        liveLlmLastCall: false,
        currentlySpeakingMessageId: zoeMsg.id,
        highlightStart: -1,
        highlightEnd: -1,
      ),
    );

    try {
      final tts = ref.read(ttsProvider);
      await tts.speak(zoeText);
    } catch (_) {
      // TTS failure is non-fatal — message is on screen already.
    }

    if (state.hasValue && state.requireValue.status == ChatStatus.zoeSpeaking) {
      state = AsyncValue.data(
        state.requireValue.copyWith(status: ChatStatus.idle),
      );
    }
  }
}

final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
