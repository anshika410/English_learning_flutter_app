// Shared entry point for starting a session on the home screen's selected topic.
// Only the "Let's Talk About …" CTA starts a session; it launches by topic name
// (the selected topic is a bare string — recommended / an alternative / a
// catalogue pick). Keeping this in one place means the POST /session flow lives
// here, not scattered across the chips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/topic_data.dart';
import '../../providers/chat_provider.dart';
import '../../providers/garden_provider.dart';
import '../../services/analytics_service.dart';
import 'session_screen.dart';

/// Starts a session on the topic named [topicName]. If the previous session
/// ended, roll to the next chat (seeded with this topic); otherwise let the
/// pushed [SessionScreen] kick it off via `initialTopic`. The level comes from
/// current memory (topic names carry no level).
Future<void> startTopicByName(
  BuildContext context,
  WidgetRef ref,
  String topicName, {
  VoidCallback? onConversationEnded,
}) async {
  AnalyticsService.logTopicSelected(topicName);
  if (ref.read(gardenPreviewEnabledProvider)) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SessionScreen(previewMode: true, onEnded: onConversationEnded),
      ),
    );
    return;
  }

  final chatState = ref.read(chatProvider);
  final level = chatState.hasValue ? chatState.requireValue.memory.level : 'A1';
  final engineTopic = Topic(
    level: level,
    theme: '',
    topic: topicName,
    starters: '',
  );

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
