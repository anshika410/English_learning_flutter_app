/// Grammar focus levels for Zoe's coaching style
enum GrammarFocus {
  passive,
  balanced,
  active;

  String get label => switch (this) {
        GrammarFocus.passive => 'Passive',
        GrammarFocus.balanced => 'Balanced',
        GrammarFocus.active => 'Active',
      };

  String get description => switch (this) {
        GrammarFocus.passive =>
          'Zoe corrects only critical errors that affect meaning.',
        GrammarFocus.balanced =>
          'Zoe offers balanced feedback on grammar patterns.',
        GrammarFocus.active =>
          'Zoe actively coaches all grammar opportunities.',
      };
}

/// Vocabulary focus levels for Zoe's coaching style
enum VocabFocus {
  minimal,
  balanced,
  aggressive;

  String get label => switch (this) {
        VocabFocus.minimal => 'Minimal',
        VocabFocus.balanced => 'Balanced',
        VocabFocus.aggressive => 'Aggressive',
      };

  String get description => switch (this) {
        VocabFocus.minimal =>
          'Zoe rarely suggests new words; focuses on what you use.',
        VocabFocus.balanced =>
          'Zoe suggests new words when they naturally fit the conversation.',
        VocabFocus.aggressive =>
          'Zoe actively introduces new vocabulary in every session.',
      };
}

/// Fluency focus levels for Zoe's coaching style
enum FluencyFocus {
  relaxed,
  balanced,
  intense;

  String get label => switch (this) {
        FluencyFocus.relaxed => 'Relaxed',
        FluencyFocus.balanced => 'Balanced',
        FluencyFocus.intense => 'Intense',
      };

  String get description => switch (this) {
        FluencyFocus.relaxed =>
          'Zoe is patient with hesitations and fillers; focuses on content.',
        FluencyFocus.balanced =>
          'Zoe gives balanced feedback on pace and flow.',
        FluencyFocus.intense =>
          'Zoe actively coaches pace, pauses, and filler words.',
      };
}

/// Combined focus settings for Zoe's coaching approach in a session
class FocusSettings {
  final GrammarFocus grammar;
  final VocabFocus vocabulary;
  final FluencyFocus fluency;

  const FocusSettings({
    required this.grammar,
    required this.vocabulary,
    required this.fluency,
  });

  /// Default coaching style (balanced across all dimensions)
  const FocusSettings.defaults()
      : grammar = GrammarFocus.balanced,
        vocabulary = VocabFocus.balanced,
        fluency = FluencyFocus.balanced;

  /// Create a copy with optional field overrides
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusSettings &&
        other.grammar == grammar &&
        other.vocabulary == vocabulary &&
        other.fluency == fluency;
  }

  @override
  int get hashCode => Object.hash(grammar, vocabulary, fluency);

  @override
  String toString() =>
      'FocusSettings(grammar: $grammar, vocabulary: $vocabulary, fluency: $fluency)';
}
