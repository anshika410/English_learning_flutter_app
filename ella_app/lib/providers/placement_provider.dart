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
import 'chat_provider.dart' show ChatStatus, chatProvider;
import 'service_providers.dart';

class PlacementState {
  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? partialStt;
  final bool started;
  final bool isComplete;
  final PlacementTurnResult? result;
  final String? error;

  const PlacementState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.partialStt,
    this.started = false,
    this.isComplete = false,
    this.result,
    this.error,
  });

  PlacementState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? partialStt,
    bool clearPartialStt = false,
    bool? started,
    bool? isComplete,
    PlacementTurnResult? result,
    String? error,
    bool clearError = false,
  }) => PlacementState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    partialStt: clearPartialStt ? null : (partialStt ?? this.partialStt),
    started: started ?? this.started,
    isComplete: isComplete ?? this.isComplete,
    result: result ?? this.result,
    error: clearError ? null : (error ?? this.error),
  );
}

class PlacementNotifier extends Notifier<PlacementState> {
  // Name/age extracted by the LLM during the screening — threaded back into
  // subsequent requests so it keeps its context.
  String? _name;
  int? _age;

  @override
  PlacementState build() => const PlacementState();

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
    state = state.copyWith(started: true, status: ChatStatus.zoeThinking);

    final api = ref.read(ellaApiServiceProvider);

    // Per the documented placement sequence, open a session record first. The
    // /llm/placement-turn endpoint itself is stateless (no session_id), so this
    // is best-effort context only and never blocks the screening.
    try {
      await api.createConversation();
    } catch (_) {}

    await _turn();
  }

  // ── User turn ───────────────────────────────────────────────────────────────

  Future<void> sendUserTurn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isComplete) return;
    if (state.status != ChatStatus.idle &&
        state.status != ChatStatus.userSpeaking) {
      return;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(sender: MessageSender.child, text: trimmed),
      ],
      status: ChatStatus.zoeThinking,
      clearPartialStt: true,
    );
    await _turn();
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
      state = state.copyWith(
        status: ChatStatus.idle,
        error: 'Placement turn failed: $e',
      );
      return;
    }

    _name = result.name ?? _name;
    _age = result.age ?? _age;

    final reply = result.reply?.trim() ?? '';
    if (reply.isNotEmpty) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(sender: MessageSender.zoe, text: reply),
        ],
        status: ChatStatus.zoeSpeaking,
        clearError: true,
      );
      try {
        await ref.read(ttsProvider).speak(reply);
      } catch (_) {}
    }

    if (result.isComplete) {
      // Backend has persisted the placement; pull the new memory + garden so the
      // gate advances and the garden renders at the placement level.
      state = state.copyWith(
        status: ChatStatus.idle,
        isComplete: true,
        result: result,
      );
      await ref.read(chatProvider.notifier).refreshAfterPlacement();
    } else {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  // ── Voice input (mirrors ChatNotifier) ────────────────────────────────────

  Future<void> startListening() async {
    if (state.status != ChatStatus.idle || state.isComplete) return;
    state = state.copyWith(status: ChatStatus.userSpeaking);
    final stt = ref.read(sttProvider);
    await stt.startListening(
      onPartial: (partial) =>
          state = state.copyWith(partialStt: partial),
      onFinal: (text) {
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
    // Safety net for platforms whose final result is slow/missing: if we're
    // still on userSpeaking after a beat, commit whatever partial we heard.
    Future.delayed(const Duration(milliseconds: 400), () {
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
  }
}

final placementProvider = NotifierProvider<PlacementNotifier, PlacementState>(
  PlacementNotifier.new,
);
