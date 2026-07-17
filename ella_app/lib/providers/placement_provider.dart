// Placement controller — the first-run voice screening state machine.
//
// Deliberately separate from ChatNotifier: placement talks to the stateless
// POST /llm/placement-turn endpoint (no session_id / topic / judge), so mixing
// it into the session engine would only add branches there. It reuses the same
// STT/TTS services and the ConversationView UI, and mirrors ChatNotifier's
// turn/listen patterns.
//
// Loop: start() asks Zoe's first question → the child answers (voice or text) →
// each answer POSTs the running transcript → Zoe's next question, until the
// backend returns is_complete with a final CEFR level. On completion the backend
// has already persisted the placement, so we ask ChatNotifier to refresh memory
// + garden (which flips the RootGate from placement → home).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../models/placement.dart';
import '../services/analytics_service.dart';
import 'chat_provider.dart' show ChatStatus, chatProvider;
import 'service_providers.dart';
import '../services/sounds.dart';

class PlacementState {
  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? partialStt;
  final bool started;
  final bool isComplete;

  /// True while the End flow is running (the "I want to end this conversation"
  /// turn is in flight) — absorbs repeat End taps.
  final bool ending;

  /// Whether the backend assigned a CEFR level, resolved from the post-
  /// completion memory refresh. Null until known; drives the bloom (true) vs
  /// sprout (false) placement-garden branch.
  final bool? levelAssigned;
  final PlacementTurnResult? result;
  final String? error;
  final String? currentlySpeakingMessageId;
  final int highlightStart;
  final int highlightEnd;

  const PlacementState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.partialStt,
    this.started = false,
    this.isComplete = false,
    this.ending = false,
    this.levelAssigned,
    this.result,
    this.error,
    this.currentlySpeakingMessageId,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  PlacementState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? partialStt,
    bool clearPartialStt = false,
    bool? started,
    bool? isComplete,
    bool? ending,
    bool? levelAssigned,
    PlacementTurnResult? result,
    String? error,
    bool clearError = false,
    String? currentlySpeakingMessageId,
    bool clearCurrentlySpeaking = false,
    int? highlightStart,
    int? highlightEnd,
  }) => PlacementState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    partialStt: clearPartialStt ? null : (partialStt ?? this.partialStt),
    started: started ?? this.started,
    isComplete: isComplete ?? this.isComplete,
    ending: ending ?? this.ending,
    levelAssigned: levelAssigned ?? this.levelAssigned,
    result: result ?? this.result,
    error: clearError ? null : (error ?? this.error),
    currentlySpeakingMessageId: clearCurrentlySpeaking
        ? null
        : (currentlySpeakingMessageId ?? this.currentlySpeakingMessageId),
    highlightStart: highlightStart ?? this.highlightStart,
    highlightEnd: highlightEnd ?? this.highlightEnd,
  );
}

class PlacementNotifier extends Notifier<PlacementState> {
  // Name/age extracted by the LLM during the screening — threaded back into
  // subsequent requests so it keeps its context.
  String? _name;
  int? _age;

  // The turn currently in flight, so endConversation() can wait for it instead
  // of posting the end message mid-turn.
  Future<void>? _inflight;

  int _activeSttSessionId = 0;
  bool _sttSessionFinalized = false;

  @override
  PlacementState build() {
    final nativeTts = ref.read(nativeTtsProvider);
    final progressSub = nativeTts.progressStream.listen((event) {
      state = state.copyWith(
        highlightStart: event.start,
        highlightEnd: event.end,
      );
    });
    final doneSub = nativeTts.doneStream.listen((_) {
      final wasSpeaking = state.currentlySpeakingMessageId != null;
      state = state.copyWith(
        status: ChatStatus.idle,
        clearCurrentlySpeaking: true,
        highlightStart: -1,
        highlightEnd: -1,
      );
      if (wasSpeaking && !state.isComplete) {
        ref.read(audioProvider).playSfx(Sounds.turn);
      }
    });
    ref.onDispose(() {
      progressSub.cancel();
      doneSub.cancel();
    });
    return const PlacementState();
  }

  /// Seed the name/age collected during onboarding so the very first
  /// placement-turn request carries them and Zoe doesn't re-ask. LLM turns may
  /// still refine these later (see [_turn]).
  void seedProfile({String? name, int? age}) {
    if (name != null && name.isNotEmpty) _name = name;
    if (age != null) _age = age;
  }

  /// Reset state to a fresh instance
  void reset() {
    _name = null;
    _age = null;
    _inflight = null;
    state = const PlacementState();
  }

  // ── Transcript shaping ──────────────────────────────────────────────────────

  /// The running transcript in the API's shape ({role, content}), zoe→assistant
  /// and child→user. System messages (if any) are dropped.
  List<Map<String, String>> _apiMessages() => [
    for (final m in state.messages)
      if (m.sender != MessageSender.system)
        {
          'role': m.sender == MessageSender.zoe ? 'assistant' : 'user',
          'content': m.text,
        },
  ];

  // ── Start ─────────────────────────────────────────────────────────────────

  /// Opens the screening: Zoe asks the first question. Idempotent — a second
  /// call while already started is a no-op.
  Future<void> start() async {
    if (state.started) return;
    AnalyticsService.logPlacementStarted();
    ref.read(audioProvider).playSfx(Sounds.start);
    state = state.copyWith(started: true, status: ChatStatus.zoeThinking);

    final api = ref.read(ellaApiServiceProvider);

    // Seed name/age from the onboarding cache so the LLM doesn't re-ask. This
    // survives PlacementIntroScreen invalidating the provider before start (an
    // in-session seedProfile() would be discarded by that invalidate).
    try {
      final cached = await api.getOnboardingState();
      _name ??= cached.name;
      _age ??= cached.age;
    } catch (_) {}

    // Per the documented placement sequence, open a session record first. The
    // /llm/placement-turn endpoint itself is stateless (no session_id), so this
    // is best-effort context only and never blocks the screening.
    try {
      await api.createConversation();
    } catch (_) {}

    await _trackedTurn();
  }

  // ── User turn ───────────────────────────────────────────────────────────────

  Future<void> sendUserTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isComplete) return;
    if (state.status != ChatStatus.idle &&
        state.status != ChatStatus.userSpeaking) {
      return;
    }
    ref.read(audioProvider).playSfx(Sounds.send);
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(sender: MessageSender.child, text: trimmed),
      ],
      status: ChatStatus.zoeThinking,
      clearPartialStt: true,
    );
    final turnNum = state.messages.where((m) => m.sender == MessageSender.child).length;
    AnalyticsService.logPlacementTurn(turnNum);
    await _trackedTurn();
  }

  /// Runs [_turn] while exposing it via [_inflight] so the End flow can await
  /// a round-trip that is already running.
  Future<void> _trackedTurn() {
    final turn = _turn().whenComplete(() => _inflight = null);
    _inflight = turn;
    return turn;
  }

  // ── End conversation (End button) ───────────────────────────────────────────

  /// Ends the screening immediately (hard end) — no farewell turn is posted.
  /// Stops voice in/out, lets any in-flight round-trip land, marks the test
  /// complete, then refreshes memory and checks whether the backend persisted
  /// a placement level: the placement garden branches on that (bloom when a
  /// level exists, sprout otherwise).
  Future<void> endConversation() async {
    if (state.ending || state.isComplete) return;
    state = state.copyWith(ending: true);

    await stopListening();
    await stopSpeaking();

    // Let any running round-trip land first — its result may already have
    // completed the screening (and persisted a level server-side).
    final inflight = _inflight;
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {}
    }

    if (!state.isComplete) {
      state = state.copyWith(isComplete: true, status: ChatStatus.idle);
      final turnNum = state.messages.where((m) => m.sender == MessageSender.child).length;
      AnalyticsService.logPlacementAbandoned(turnNum);
    }

    // Hard check: pull the freshest memory and branch on placement level.
    await ref.read(chatProvider.notifier).refreshAfterPlacement();
    _resolveLevelAssigned();
  }

  /// Resolves [PlacementState.levelAssigned] from the freshest memory (after
  /// refreshAfterPlacement), falling back to the turn result when the refresh
  /// couldn't run (offline / failed).
  void _resolveLevelAssigned() {
    final mem = ref.read(chatProvider).valueOrNull?.memory;
    final assigned =
        (mem?.hasLevel ?? false) || (state.result?.level != null);
    state = state.copyWith(levelAssigned: assigned);
  }

  /// One placement-turn round-trip: POST the running transcript, then speak
  /// Zoe's reply (question or closing line). When the backend signals
  /// completion, capture the result and refresh memory + garden.
  Future<void> _turn() async {
    final api = ref.read(ellaApiServiceProvider);
    PlacementTurnResult result;
    try {
      result = await api.placementTurn(
        messages: _apiMessages(),
        name: _name,
        age: _age,
      );
    } catch (e) {
      // Keep the child unstuck: surface the error and return to idle so they can
      // retry their turn.
      AnalyticsService.logPlacementFailed(e.toString());
      state = state.copyWith(
        status: ChatStatus.idle,
        error: "Zoe couldn't connect. Check your internet and try again",
      );
      return;
    }

    _name = result.name ?? _name;
    _age = result.age ?? _age;

    final reply = result.reply?.trim() ?? '';
    if (reply.isNotEmpty) {
      final zoeMsg = ChatMessage(sender: MessageSender.zoe, text: reply);
      state = state.copyWith(
        messages: [
          ...state.messages,
          zoeMsg,
        ],
        status: ChatStatus.zoeSpeaking,
        clearError: true,
        currentlySpeakingMessageId: zoeMsg.id,
        highlightStart: -1,
        highlightEnd: -1,
      );
      try {
        await ref.read(ttsProvider).speak(reply);
      } catch (_) {}
    }

    if (result.isComplete) {
      ref.read(audioProvider).playSfx(Sounds.complete);
      // Backend has persisted the placement; pull the new memory + garden so the
      // gate advances and the garden renders at the placement level.
      state = state.copyWith(
        status: ChatStatus.idle,
        isComplete: true,
        result: result,
      );
      try {
        final finalLevel = result.level ?? 'A0';
        await AnalyticsService.logPlacementComplete(finalLevel, 0);
        final userId = await ref.read(ellaApiServiceProvider).getCachedUserId();
        if (userId != null) {
          await AnalyticsService.setUserProfile(userId: userId, level: finalLevel);
        }
      } catch (_) {}
      await ref.read(chatProvider.notifier).refreshAfterPlacement();
      _resolveLevelAssigned();
    } else {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  // ── Voice input (mirrors ChatNotifier) ────────────────────────────────────

  Future<void> startListening() async {
    if (state.status != ChatStatus.idle || state.isComplete) return;

    _sttSessionFinalized = false;
    final sessionId = ++_activeSttSessionId;

    state = state.copyWith(status: ChatStatus.userSpeaking);
    ref.read(audioProvider).playSfx(Sounds.listen);
    final stt = ref.read(sttProvider);
    // Lazily init STT (idempotent) so the mic-permission prompt appears on first
    // voice use rather than at app/screen load.
    await stt.initialize();
    await stt.startListening(
      onPartial: (partial) {
        if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
        state = state.copyWith(partialStt: partial);
      },
      onFinal: (text) {
        if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
        _sttSessionFinalized = true;

        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          sendUserTurn(trimmed);
        } else {
          state = state.copyWith(
            status: ChatStatus.idle,
            clearPartialStt: true,
          );
        }
      },
    );
  }

  Future<void> stopListening() async {
    await ref.read(sttProvider).stopListening();
    
    final sessionId = _activeSttSessionId;

    // Safety net for platforms whose final result is slow/missing: if we're
    // still on userSpeaking after a beat, commit whatever partial we heard.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (sessionId != _activeSttSessionId || _sttSessionFinalized) return;
      _sttSessionFinalized = true;

      if (state.status != ChatStatus.userSpeaking) return;
      final partial = state.partialStt?.trim() ?? '';
      if (partial.isNotEmpty) {
        sendUserTurn(partial);
      } else {
        state = state.copyWith(status: ChatStatus.idle, clearPartialStt: true);
      }
    });
  }

  Future<void> stopSpeaking() async {
    try {
      await ref.read(ttsProvider).stop();
    } catch (_) {}
    // Some platforms don't fire the completion handler on stop(), which would
    // leave the status stuck on zoeSpeaking (and the speaker toggle "active").
    if (state.status == ChatStatus.zoeSpeaking) {
      state = state.copyWith(
        status: ChatStatus.idle,
        clearCurrentlySpeaking: true,
        highlightStart: -1,
        highlightEnd: -1,
      );
    }
  }

  Future<void> replayZoeLine(String text) async {
    if (state.status != ChatStatus.idle || state.isComplete) return;
    state = state.copyWith(
      status: ChatStatus.zoeSpeaking,
      highlightStart: -1,
      highlightEnd: -1,
    );
    try {
      await ref.read(ttsProvider).speak(text);
    } catch (_) {}
    state = state.copyWith(
      status: ChatStatus.idle,
      highlightStart: -1,
      highlightEnd: -1,
    );
  }
}

final placementProvider = NotifierProvider<PlacementNotifier, PlacementState>(
  PlacementNotifier.new,
);
