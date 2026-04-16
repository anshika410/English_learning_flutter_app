// Focus settings for Zoe's coaching style.
// Only shown to B1+ users. A1/A2 get defaults silently.

enum GrammarFocus {
  off,
  some,
  catchAll,
  full;

  String get label {
    switch (this) {
      case GrammarFocus.off:
        return 'Off';
      case GrammarFocus.some:
        return 'Some';
      case GrammarFocus.catchAll:
        return 'Catch All';
      case GrammarFocus.full:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case GrammarFocus.off:
        return 'Zoe will not mention grammar errors.';
      case GrammarFocus.some:
        return 'Zoe highlights only the most important grammar slips.';
      case GrammarFocus.catchAll:
        return 'Metalinguistic feedback on errors — the default coaching mode.';
      case GrammarFocus.full:
        return 'Zoe corrects every grammar error with a full explanation.';
    }
  }
}

enum VocabFocus {
  off,
  post,
  occasional,
  active,
  intensive;

  String get label {
    switch (this) {
      case VocabFocus.off:
        return 'Off';
      case VocabFocus.post:
        return 'Post';
      case VocabFocus.occasional:
        return 'Occasional';
      case VocabFocus.active:
        return 'Active';
      case VocabFocus.intensive:
        return 'Intensive';
    }
  }

  String get description {
    switch (this) {
      case VocabFocus.off:
        return 'Zoe will not suggest new words.';
      case VocabFocus.post:
        return 'New words shared after the conversation, not during.';
      case VocabFocus.occasional:
        return 'Mid-conversation, max 2 new words per session.';
      case VocabFocus.active:
        return 'Zoe actively introduces and reinforces new words.';
      case VocabFocus.intensive:
        return 'Heavy vocabulary work — new words woven into every exchange.';
    }
  }
}

enum FluencyFocus {
  off,
  afterChat,
  nudge,
  active,
  full;

  String get label {
    switch (this) {
      case FluencyFocus.off:
        return 'Off';
      case FluencyFocus.afterChat:
        return 'After Chat';
      case FluencyFocus.nudge:
        return 'Nudge';
      case FluencyFocus.active:
        return 'Active';
      case FluencyFocus.full:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case FluencyFocus.off:
        return 'No pace or fluency tracking.';
      case FluencyFocus.afterChat:
        return 'WPM and filler words reported in post-session summary.';
      case FluencyFocus.nudge:
        return 'Zoe gently nudges you if you slow down or pause too long.';
      case FluencyFocus.active:
        return 'Zoe actively coaches pace and filler reduction mid-conversation.';
      case FluencyFocus.full:
        return 'Intensive fluency coaching — pace, fillers, and rhythm every turn.';
    }
  }
}

class FocusSettings {
  final GrammarFocus grammar;
  final VocabFocus vocabulary;
  final FluencyFocus fluency;

  const FocusSettings({
    required this.grammar,
    required this.vocabulary,
    required this.fluency,
  });

  /// Default settings applied for all levels. A1/A2 use these silently.
  /// B1+ can customise via profile or the discovery screen.
  const FocusSettings.defaults()
      : grammar = GrammarFocus.catchAll,
        vocabulary = VocabFocus.occasional,
        fluency = FluencyFocus.afterChat;

  FocusSettings copyWith({
    GrammarFocus? grammar,
    VocabFocus? vocabulary,
    FluencyFocus? fluency,
  }) {
    return FocusSettings(
      grammar: grammar ?? this.grammar,
      vocabulary: vocabulary ?? this.vocabulary,
      fluency: fluency ?? this.fluency,
    );
  }
}
