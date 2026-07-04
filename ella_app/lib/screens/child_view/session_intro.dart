import '../../core/engine.dart';
import '../../models/child_memory.dart';

/// The greeting shown on the Home screen and the garden "Let's Talk" bar —
/// "Yesterday, we talked about X. Today, I wanted to talk about Y. Shall we?".
/// Derived live from memory so both surfaces stay in sync.
String buildHomeGreeting(MemoryState? mem) {
  if (mem == null) return 'Getting things ready…';
  final proposal = pickTopic(mem)?.topic;
  final callback = mem.lastTopics.isNotEmpty ? mem.lastTopics.first : null;
  final parts = <String>[];
  if (callback != null) {
    parts.add('Yesterday, we talked about $callback.');
  }
  if (proposal != null) {
    parts.add('Today, I wanted to talk about $proposal. Shall we?');
  } else if (callback != null) {
    parts.add('Want to keep going?');
  } else {
    parts.add("Let's talk about something fun today. Shall we?");
  }
  return parts.join(' ');
}

String buildSessionIntroText({String? override, String? topicText}) {
  final explicit = override?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final topic = topicText?.trim();
  if (topic != null && topic.isNotEmpty) {
    return 'Today, I wanted to talk about $topic. Shall we?';
  }

  return 'Ready when you are. Shall we?';
}
