enum ConversationFeeling {
  notGreat('not_great'),
  okay('okay'),
  great('great');

  final String apiValue;

  const ConversationFeeling(this.apiValue);
}

enum ConversationEndReason {
  automatic('automatic'),
  manual('manual');

  final String analyticsValue;

  const ConversationEndReason(this.analyticsValue);
}

class ConversationEndContext {
  final String? sessionId;
  final int conversationNumber;
  final int turnCount;
  final ConversationEndReason reason;

  const ConversationEndContext({
    required this.sessionId,
    required this.conversationNumber,
    required this.turnCount,
    required this.reason,
  });
}

bool shouldShowFeelingCheckIn(int conversationNumber) =>
    conversationNumber >= 2 && conversationNumber % 2 == 0;
