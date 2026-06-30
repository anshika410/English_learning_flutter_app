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
