// Shared entry point for starting a session on a chosen home-screen topic.
// Used by both the home chips and the "See More" screen so the session-start
// flow (POST /session with the tapped topic) lives in exactly one place.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/home_topic.dart';
import '../../providers/chat_provider.dart';
import 'session_screen.dart';

/// Starts a session on [topic]. Mirrors the CTA flow: if the previous session
/// ended, roll to the next chat (seeded with this topic), then push the session
/// screen. On a fresh state the SessionScreen kicks off the session itself via
/// `initialTopic`. The topic's level comes from current memory (topics payload
/// carries no level).
Future<void> startTopicSession(
  BuildContext context,
  WidgetRef ref,
  HomeTopic topic, {
  VoidCallback? onConversationEnded,
}) async {
  final chatState = ref.read(chatProvider);
  final level =
      chatState.hasValue ? chatState.requireValue.memory.level : 'A1';
  final engineTopic = topic.toEngineTopic(level);

  if (chatState.hasValue && chatState.requireValue.sessionEnded) {
    // nextChat starts the session with our topic; SessionScreen then no-ops.
    await ref.read(chatProvider.notifier).nextChat(topicOverride: engineTopic);
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SessionScreen(
        initialTopic: engineTopic,
        onEnded: onConversationEnded,
      ),
    ),
  );
}

/// Best-effort parse of the CSS-ish colour strings the topics API returns
/// (`#RRGGBB`, `#AARRGGBB`, or `rgba(r,g,b,a)`). Returns null on anything else
/// (e.g. gradients) so callers can fall back to a theme colour.
Color? parseCssColor(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.startsWith('#')) {
    var hex = s.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  if (s.startsWith('rgba(') || s.startsWith('rgb(')) {
    final inner = s.substring(s.indexOf('(') + 1, s.length - 1);
    final parts = inner.split(',').map((p) => p.trim()).toList();
    if (parts.length < 3) return null;
    final r = int.tryParse(parts[0]);
    final g = int.tryParse(parts[1]);
    final b = int.tryParse(parts[2]);
    if (r == null || g == null || b == null) return null;
    final a = parts.length >= 4 ? (double.tryParse(parts[3]) ?? 1.0) : 1.0;
    return Color.fromARGB((a * 255).round(), r, g, b);
  }

  return null;
}
