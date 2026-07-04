class EndResultTranscriptNote {
  final String speaker; // 'student' | 'zoe'
  final String text;
  final String? note; // null for zoe turns

  const EndResultTranscriptNote({
    required this.speaker,
    required this.text,
    this.note,
  });
}

class EndResultAnalysis {
  final String overall; // 'good' | 'okay' | 'struggling'
  final String bestMomentQuote;
  final String bestMomentNote;
  final String courageOrMotivationType; // 'moment_of_courage' | 'motivation'
  final String courageOrMotivationContent;
  final String tryNextTimeSkill;
  final String tryNextTimeExample;
  final List<EndResultTranscriptNote> transcriptNotes;

  const EndResultAnalysis({
    required this.overall,
    required this.bestMomentQuote,
    required this.bestMomentNote,
    required this.courageOrMotivationType,
    required this.courageOrMotivationContent,
    required this.tryNextTimeSkill,
    required this.tryNextTimeExample,
    required this.transcriptNotes,
  });
}
