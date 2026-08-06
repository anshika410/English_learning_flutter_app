// Shared entry point for starting a session on the home screen's selected topic.
// Only the "Let's Talk About …" CTA starts a session. It launches with the rich
// TopicChoice so presentation metadata survives navigation while the full topic
// name remains the POST /session value. Keeping this in one place means the
// session flow does not get scattered across the topic widgets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/topic_data.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import '../../services/analytics_service.dart';
import 'session_screen.dart';
import 'widgets/topic_handoff.dart';

/// Starts a session for [topic]. The full name is sent to the engine/API while
/// its short label and icon stay available to the conversation presentation.
Future<void> startTopic(
  BuildContext context,
  WidgetRef ref,
  TopicChoice topic, {
  VoidCallback? onConversationEnded,
}) async {
  AnalyticsService.logTopicSelected(topic.name);
  final chatState = ref.read(chatProvider);
  final level = chatState.hasValue ? chatState.requireValue.memory.level : 'A1';
  final engineTopic = Topic(
    level: level,
    theme: '',
    topic: topic.name,
    starters: '',
  );

  if (chatState.hasValue && chatState.requireValue.sessionEnded) {
    // Reset synchronously, then let SessionScreen start the network work after
    // it mounts. This keeps the topic flight visible during slow startup.
    ref.read(chatProvider.notifier).prepareNextChat();
  }
  if (!context.mounted) return;
  final reducedMotion = MediaQuery.of(context).disableAnimations;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: reducedMotion
          ? Duration.zero
          : kTopicHandoffFlightDuration,
      reverseTransitionDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => SessionScreen(
        initialTopic: engineTopic,
        topicPresentation: topic,
        onEnded: onConversationEnded,
      ),
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}
