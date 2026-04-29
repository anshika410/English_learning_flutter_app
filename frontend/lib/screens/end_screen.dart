import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../providers/chat_provider.dart';
import '../theme/ella_theme.dart';
import '../theme/ella_responsive.dart';
import '../widgets/ella_primary_button.dart';
import 'home_screen.dart';
import 'conversation_screen.dart';

// ─── Session Type ──────────────────────────────────────────────────────────────

enum SessionType {
  /// User never spoke — only Zoe's opener was played
  empty,

  /// 1–4 full exchanges (user turned at least once but not a full session)
  partial,

  /// 5+ full exchanges — a complete session
  full,
}

// ─── Conversation Quality ─────────────────────────────────────────────────────

enum ConversationQuality { great, okayish, struggling }

// ─── Session Summary ──────────────────────────────────────────────────────────

class SessionSummary {
  final String bestMoment;
  final String? wordOfSession;
  final String? wordType;
  final bool wordIsTryMode;
  final String? courageText;
  final String? habitText;
  final String stickyLabel;
  final String stickyText;
  final String? llmHeadline;

  const SessionSummary({
    required this.bestMoment,
    this.wordOfSession,
    this.wordType,
    this.wordIsTryMode = false,
    this.courageText,
    this.habitText,
    required this.stickyLabel,
    required this.stickyText,
    this.llmHeadline,
  });

  factory SessionSummary.mockForQuality(ConversationQuality quality) {
    switch (quality) {
      case ConversationQuality.great:
        return const SessionSummary(
          bestMoment:
              '"You used \'usually\' correctly 3 times — that\'s real progress!"',
          wordOfSession: 'usually',
          wordType: 'adverb · used ×3 today',
          wordIsTryMode: false,
          courageText: 'First time trying the past perfect — and you nailed it',
          habitText: null,
          stickyLabel: 'One thing to try next time',
          stickyText: 'Irregular past tense — "I ate" not "I eated"',
        );
      case ConversationQuality.okayish:
        return const SessionSummary(
          bestMoment:
              '"You kept going for nearly 3 minutes without switching to Hindi — that takes real discipline."',
          wordOfSession: 'nervous',
          wordType: 'adjective · used once',
          wordIsTryMode: false,
          courageText:
              'You stayed in English even when it got hard — that\'s exactly the habit to build.',
          habitText: null,
          stickyLabel: 'Something to focus on',
          stickyText: 'Try asking Zoe a question next time — any question',
        );
      case ConversationQuality.struggling:
        return const SessionSummary(
          bestMoment:
              '"You asked a question in English. That\'s exactly the point of this."',
          wordOfSession: 'usually',
          wordType: 'try using this next time',
          wordIsTryMode: true,
          courageText: null,
          habitText: 'Coming back tomorrow matters more than today\'s mistakes',
          stickyLabel: 'One thing to try next time',
          stickyText:
              'Slow down a little — one clear sentence is better than three rushed ones',
        );
    }
  }
}

// ─── Mock transcript data ─────────────────────────────────────────────────────

class _TranscriptEntry {
  final bool isElla;
  final String text;
  final String? correction;
  _TranscriptEntry(this.isElla, this.text, {this.correction});
}

final List<_TranscriptEntry> _mockTranscript = [
  _TranscriptEntry(
    true,
    "Hey! Let's talk about daily routine. What time do you usually wake up?",
  ),
  _TranscriptEntry(
    false,
    "I usually wake up at 7 in the morning.",
    correction: 'Great use of "usually"! ✓',
  ),
  _TranscriptEntry(
    true,
    "Nice! And what do you do first thing in the morning?",
  ),
  _TranscriptEntry(
    false,
    "I eated breakfast and then check my phone.",
    correction:
        'Correction: "ate" not "eated" — past tense of eat is irregular.',
  ),
  _TranscriptEntry(true, "I see! What helps you feel energised for the day?"),
  _TranscriptEntry(
    false,
    "Honestly, I also feel better after a short walk outside.",
  ),
];

// ─── EndScreen ────────────────────────────────────────────────────────────────

class EndScreen extends StatelessWidget {
  final String topic;
  final String? retryTopic;
  final String durationLabel;
  final SessionType sessionType;
  final ConversationQuality quality;
  final SessionSummary? summary;
  final Future<EndResultAnalysis?>? analysisFuture;

  const EndScreen({
    super.key,
    required this.topic,
    this.retryTopic,
    required this.durationLabel,
    this.sessionType = SessionType.full,
    this.quality = ConversationQuality.great,
    this.summary,
    this.analysisFuture,
  });

  void _showTranscriptSheet(
    BuildContext context,
    List<EndResultTranscriptNote> transcriptNotes,
  ) {
    final messages = context.read<ChatProvider>().messages;

    final entries = messages
        .where(
          (m) => m.role == MessageRole.user || m.role == MessageRole.assistant,
        )
        .map((m) {
          final isElla = m.role == MessageRole.assistant;
          String? note;
          if (!isElla) {
            final match = transcriptNotes.where(
              (n) =>
                  n.speaker == 'student' &&
                  n.note != null &&
                  m.content.contains(n.text.split(' ').first),
            );
            if (match.isNotEmpty) note = match.first.note;
          }
          return _TranscriptEntry(isElla, m.content, correction: note);
        })
        .toList();

    final displayEntries = entries.isEmpty ? _mockTranscript : entries;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (sheetCtx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: EllaColors.neutralBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EllaColors.neutralBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Full Transcript',
                style: TextStyle(
                  fontFamily: 'Chillax',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.neutralPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: displayEntries.length,
                  itemBuilder: (ctx2, i) =>
                      _TranscriptRow(entry: displayEntries[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _pickNewTopic(BuildContext context) {
    _goToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return switch (sessionType) {
      SessionType.empty => _buildEmptyScreen(context),
      SessionType.partial => _buildSummaryScreen(context),
      SessionType.full => _buildSummaryScreen(context),
    };
  }

  // ── Empty: user never spoke ──────────────────────────────────────────────────

  Widget _buildEmptyScreen(BuildContext context) {
    final isWide = EllaResponsive.isWide(context);
    final viewport = MediaQuery.of(context).size;
    final mascotSize = isWide
        ? 120.0
        : viewport.shortestSide < 380
            ? 160.0
            : 200.0;

    void tryAgain() {
      final restartTopic = retryTopic ?? topic;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(topic: restartTopic),
        ),
      );
    }

    Widget actionRow() {
      return Row(
        mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Flexible(
            child: SizedBox(
              width: isWide ? 180 : double.infinity,
              child: _GhostButton(
                label: 'PICK NEW TOPIC',
                onTap: () => _pickNewTopic(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SizedBox(
              width: isWide ? 152 : double.infinity,
              child: EllaPrimaryButton(
                label: 'TRY AGAIN',
                onTap: tryAgain,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 460 : 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: mascotSize,
                          height: mascotSize,
                          decoration: BoxDecoration(
                            color: EllaColors.zoeMintLight,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: EllaColors.neutralMuted.withValues(
                                  alpha: 0.40,
                                ),
                                offset: const Offset(0, 6),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                offset: const Offset(0, 3),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _ZoeMascotAnimator(size: mascotSize),
                          ),
                        ),
                        SizedBox(height: isWide ? 24 : 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Looks like we lost you there.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Chillax',
                              fontSize: isWide ? 22 : 24,
                              fontWeight: FontWeight.w600,
                              color: EllaColors.neutralPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No chat happened — that\'s okay. Want to try a fresh start?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: EllaColors.neutralSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (isWide) ...[
                          const SizedBox(height: 48),
                          actionRow(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!isWide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Center(child: actionRow()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Partial / Full: the rich summary screen ───────────────────────────────────

  Widget _buildSummaryScreen(BuildContext context) {
    if (analysisFuture != null) {
      return FutureBuilder<EndResultAnalysis?>(
        future: analysisFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _buildAnalysisLoader();
          }
          final analysis = snap.data;
          SessionSummary effectiveSummary;
          ConversationQuality effectiveQuality;
          List<EndResultTranscriptNote> notes = const [];
          if (analysis != null) {
            effectiveQuality = _qualityFrom(analysis.overall);
            effectiveSummary = _summaryFrom(analysis, effectiveQuality);
            notes = analysis.transcriptNotes;
          } else {
            effectiveQuality = quality;
            effectiveSummary =
                summary ?? SessionSummary.mockForQuality(quality);
          }
          return _buildSummaryScaffold(
            context,
            effectiveSummary,
            effectiveQuality,
            notes,
          );
        },
      );
    }

    return _buildSummaryScaffold(
      context,
      summary ?? SessionSummary.mockForQuality(quality),
      quality,
      const [],
    );
  }

  ConversationQuality _qualityFrom(String overall) {
    switch (overall) {
      case 'good':
        return ConversationQuality.great;
      case 'struggling':
        return ConversationQuality.struggling;
      default:
        return ConversationQuality.okayish;
    }
  }

  SessionSummary _summaryFrom(
    EndResultAnalysis analysis,
    ConversationQuality q,
  ) {
    final isStruggling = q == ConversationQuality.struggling;
    return SessionSummary(
      bestMoment: '"${analysis.bestMomentQuote}"',
      wordOfSession: analysis.wordOfDay,
      wordType: analysis.wordOfDayLabel,
      wordIsTryMode: isStruggling,
      courageText: analysis.courageOrMotivationContent,
      habitText: isStruggling ? analysis.courageOrMotivationContent : null,
      stickyLabel: 'One thing to try next time',
      stickyText:
          '${analysis.tryNextTimeSkill}\n\n"${analysis.tryNextTimeExample}"',
      llmHeadline: analysis.headline,
    );
  }

  Widget _buildAnalysisLoader() {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _GradientGridBackground()),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: EllaColors.zoeMintLight,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/mascot-animations/juggling.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'We had a great conversation,\ngive me a second…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScaffold(
    BuildContext context,
    SessionSummary effectiveSummary,
    ConversationQuality effectiveQuality,
    List<EndResultTranscriptNote> transcriptNotes,
  ) {
    final (fallbackHeadline, emoji) = switch (effectiveQuality) {
      ConversationQuality.great => ('Great Conversation!', '🌟'),
      ConversationQuality.okayish => ('Good Effort Today', '✨'),
      ConversationQuality.struggling => ('Every Session Counts', '🌱'),
    };

    final displayHeadline = effectiveSummary.llmHeadline ?? fallbackHeadline;

    final isWide = EllaResponsive.isWide(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final sidePad = isWide
        ? ((screenWidth - 768) / 2).clamp(24.0, double.infinity)
        : 24.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final headerHeight =
        MediaQuery.paddingOf(context).top +
        (isWide ? 260.0 : 340.0) * textScale.clamp(1.0, 1.25);

    // Courage text: always show for all quality states
    final courageText =
        effectiveSummary.courageText ?? effectiveSummary.habitText ?? '';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _GradientGridBackground()),
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SummaryHeaderDelegate(
                  height: headerHeight,
                  child: _SummaryHeaderCard(
                    headline: displayHeadline,
                    emoji: emoji,
                    durationLabel: durationLabel,
                    topic: topic,
                    isWide: isWide,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(sidePad, 24, sidePad, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Best Moment + Courage side by side
                    _buildMomentCards(
                      isWide: isWide,
                      bestMoment: effectiveSummary.bestMoment,
                      courageText: courageText,
                      quality: effectiveQuality,
                    ),
                    const SizedBox(height: 32),

                    // Sticky note — centered, max 480px
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _StickyNote(
                            label: effectiveSummary.stickyLabel,
                            text: effectiveSummary.stickyText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Bottom row: word of day + transcript — centered as a group
                    _buildBottomRow(
                      context: context,
                      word: effectiveSummary.wordOfSession,
                      wordLabel: effectiveSummary.wordType,
                      isTryMode: effectiveSummary.wordIsTryMode,
                      transcriptNotes: transcriptNotes,
                      isWide: isWide,
                    ),
                    // On wide: button inline after content; on mobile: space for sticky overlay
                    if (isWide) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: IntrinsicWidth(
                          child: EllaPrimaryButton(
                            label: 'PICK NEW TOPIC',
                            onTap: () => _pickNewTopic(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ] else
                      const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),

          // Sticky blurred PICK NEW TOPIC button — mobile only
          if (!isWide)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          EllaColors.neutralBg.withValues(alpha: 0.95),
                          EllaColors.neutralBg.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: EllaPrimaryButton(
                          label: 'PICK NEW TOPIC',
                          onTap: () => _pickNewTopic(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMomentCards({
    required bool isWide,
    required String bestMoment,
    required String courageText,
    required ConversationQuality quality,
  }) {
    final bestCard = _QuoteBalloon(text: bestMoment);
    final courageCard = _CourageCard(text: courageText, quality: quality);

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: bestCard),
            const SizedBox(width: 16),
            Expanded(child: courageCard),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bestCard, const SizedBox(height: 16), courageCard],
    );
  }

  Widget _buildBottomRow({
    required BuildContext context,
    required String? word,
    required String? wordLabel,
    required bool isTryMode,
    required List<EndResultTranscriptNote> transcriptNotes,
    required bool isWide,
  }) {
    final transcriptLink = _TranscriptLink(
      onTap: () => _showTranscriptSheet(context, transcriptNotes),
    );

    if (word == null) {
      return Center(child: transcriptLink);
    }

    final wordSection = _WordOfDaySection(
      word: word,
      subText: wordLabel ?? '',
      isTryMode: isTryMode,
    );

    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wordSection,
          const SizedBox(width: 32),
          transcriptLink,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: wordSection),
        const SizedBox(width: 24),
        transcriptLink,
      ],
    );
  }
}

// ─── Gradient + Dashed Grid Background ────────────────────────────────────────

class _GradientGridBackground extends StatelessWidget {
  const _GradientGridBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EllaColors.mangoLightest,
                EllaColors.roseLightest,
                EllaColors.mangoLight.withValues(alpha: 0.30),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EllaColors.neutralBorder.withValues(alpha: 0.50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    const dashLen = 3.0;
    const gapLen = 5.0;

    for (double x = 0; x <= size.width; x += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(x, 0),
        Offset(x, size.height),
        dashLen,
        gapLen,
      );
    }
    for (double y = 0; y <= size.height; y += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(0, y),
        Offset(size.width, y),
        dashLen,
        gapLen,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashLen,
    double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = Offset(dx, dy).distance;
    if (len == 0) return;
    final normX = dx / len;
    final normY = dy / len;
    double dist = 0;
    while (dist < len) {
      final dashEnd = (dist + dashLen).clamp(0.0, len);
      canvas.drawLine(
        Offset(start.dx + normX * dist, start.dy + normY * dist),
        Offset(start.dx + normX * dashEnd, start.dy + normY * dashEnd),
        paint,
      );
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ─── Summary Header Card ──────────────────────────────────────────────────────

class _SummaryHeaderCard extends StatefulWidget {
  final String headline;
  final String emoji;
  final String durationLabel;
  final String topic;
  final bool isWide;

  const _SummaryHeaderCard({
    required this.headline,
    required this.emoji,
    required this.durationLabel,
    required this.topic,
    required this.isWide,
  });

  @override
  State<_SummaryHeaderCard> createState() => _SummaryHeaderCardState();
}

class _SummaryHeaderCardState extends State<_SummaryHeaderCard> {
  late final ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _confettiCtrl.play();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mascotSize = 120.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: EllaColors.mangoLightest,
        boxShadow: [
          BoxShadow(
            color: EllaColors.mangoDark,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti burst from top center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirection: math.pi / 2,
              maxBlastForce: 12,
              minBlastForce: 4,
              emissionFrequency: 0.06,
              numberOfParticles: 18,
              gravity: 0.08,
              shouldLoop: false,
              colors: const [
                Colors.white,
                Color(0xFFFFF3E0),
                EllaColors.mangoLight,
                Color(0xFFFFE0A0),
              ],
            ),
          ),

          // Header content: mascot top-center, text below
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Zoe mascot — 120×120, centered
                  Container(
                    width: mascotSize,
                    height: mascotSize,
                    decoration: BoxDecoration(
                      color: EllaColors.zoeMintLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _ZoeMascotAnimator(size: mascotSize),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SESSION COMPLETE eyebrow
                  Text(
                    'SESSION COMPLETE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inconsolata(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: EllaColors.mangoDark.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Emoji + headline
                  Text(
                    '${widget.emoji} ${widget.headline}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Chillax',
                      fontSize: widget.isWide ? 28 : 22,
                      fontWeight: FontWeight.w700,
                      color: EllaColors.neutralPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Duration + topic chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: 'Duration · ${widget.durationLabel}',
                      ),
                      _MetaChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Topic · ${widget.topic}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Header Delegate (for pinned sticky header) ───────────────────────

class _SummaryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _SummaryHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(_SummaryHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

// ─── Meta Chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: EllaColors.neutralBorder.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: EllaColors.mangoDark.withValues(alpha: 0.70),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EllaColors.neutralSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zoe Mascot Animator ──────────────────────────────────────────────────────

class _ZoeMascotAnimator extends StatefulWidget {
  final double size;
  const _ZoeMascotAnimator({this.size = 72});

  @override
  State<_ZoeMascotAnimator> createState() => _ZoeMascotAnimatorState();
}

class _ZoeMascotAnimatorState extends State<_ZoeMascotAnimator> {
  static const _assets = [
    'assets/mascot-animations/listening.webp',
    'assets/mascot-animations/juggling.webp',
    'assets/mascot-animations/listening.webp',
    'assets/mascot-animations/bubblepop.webp',
  ];
  static const _durations = [
    Duration(seconds: 4),
    Duration(seconds: 4),
    Duration(seconds: 4),
    Duration(seconds: 3),
  ];
  static const _crossfadeDuration = Duration(milliseconds: 500);

  int _step = 0;
  double _opacityCurrent = 1.0;
  double _opacityNext = 0.0;
  int _nextStep = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _timer = Timer(_durations[_step], _crossfade);
  }

  void _crossfade() {
    if (!mounted) return;
    _nextStep = (_step + 1) % _assets.length;
    setState(() {
      _opacityCurrent = 0.0;
      _opacityNext = 1.0;
    });
    _timer = Timer(_crossfadeDuration, () {
      if (!mounted) return;
      setState(() {
        _step = _nextStep;
        _opacityCurrent = 1.0;
        _opacityNext = 0.0;
      });
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ClipOval(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          children: [
            AnimatedOpacity(
              opacity: _opacityCurrent,
              duration: _crossfadeDuration,
              child: Image.asset(
                _assets[_step],
                width: s,
                height: s,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            AnimatedOpacity(
              opacity: _opacityNext,
              duration: _crossfadeDuration,
              child: Image.asset(
                _assets[_nextStep],
                width: s,
                height: s,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quote Balloon (Best Moment card) ─────────────────────────────────────────

class _QuoteBalloon extends StatelessWidget {
  final String text;
  const _QuoteBalloon({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: EllaColors.mangoLight, width: 2),
        boxShadow: const [
          BoxShadow(
            color: EllaColors.mangoLight,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: EllaColors.mangoMain,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'BEST MOMENT',
                style: GoogleFonts.inconsolata(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: EllaColors.mangoDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            text,
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: EllaColors.neutralPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Courage Card (always shown, all quality states) ─────────────────────────

class _CourageCard extends StatefulWidget {
  final String text;
  final ConversationQuality quality;
  const _CourageCard({required this.text, required this.quality});

  @override
  State<_CourageCard> createState() => _CourageCardState();
}

class _CourageCardState extends State<_CourageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 85),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 7,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 8,
      ),
    ]).animate(_ctrl);
    _rotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: -0.087, end: -0.087), weight: 85),
      TweenSequenceItem(tween: Tween(begin: -0.087, end: 0.087), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 0.087, end: -0.087), weight: 8),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStruggling = widget.quality == ConversationQuality.struggling;
    final emoji = isStruggling ? '🔥' : '⚡';
    final label = isStruggling ? 'KEEP THE HABIT' : 'MOMENT OF COURAGE';
    final labelColor = isStruggling
        ? EllaColors.limeDark
        : EllaColors.grapeDark;
    final textColor = isStruggling ? EllaColors.limeDark : EllaColors.grapeDark;
    final borderColor = isStruggling
        ? EllaColors.limeLight
        : EllaColors.grapeLightest;
    final shadowColor = isStruggling
        ? EllaColors.limeLight.withValues(alpha: 0.8)
        : EllaColors.grapeLightest.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => Transform.rotate(
                  angle: _rotate.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inconsolata(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            widget.text,
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Word of Day Section ──────────────────────────────────────────────────────

class _WordOfDaySection extends StatelessWidget {
  final String word;
  final String subText;
  final bool isTryMode;

  const _WordOfDaySection({
    required this.word,
    required this.subText,
    required this.isTryMode,
  });

  @override
  Widget build(BuildContext context) {
    final wordColor = isTryMode ? EllaColors.mangoDark : EllaColors.skyDark;
    final underlineColor = isTryMode
        ? EllaColors.mangoLight
        : EllaColors.skyLight;
    final icon = isTryMode ? '🎯' : '📖';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          word,
          softWrap: true,
          style: TextStyle(
            fontFamily: 'Chillax',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: wordColor,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: underlineColor,
            decorationThickness: 2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subText,
          softWrap: true,
          style: GoogleFonts.baloo2(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Transcript Link ──────────────────────────────────────────────────────────

class _TranscriptLink extends StatelessWidget {
  final VoidCallback onTap;
  const _TranscriptLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📄', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            'FULL CONVERSATION',
            style: GoogleFonts.inconsolata(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: EllaColors.neutralMuted,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Read transcript',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EllaColors.neutralSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: EllaColors.neutralBorder,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '→',
                    style: TextStyle(
                      fontSize: 11,
                      color: EllaColors.neutralSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sticky Note ──────────────────────────────────────────────────────────────

class _StickyNote extends StatelessWidget {
  final String label;
  final String text;

  const _StickyNote({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.026,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDE7),
              border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(3),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40C8AA00),
                  offset: Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inconsolata(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: const Color(0xFFA08000),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: EllaColors.neutralPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          // Pin dot at top center
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: EllaColors.mangoMain,
                  shape: BoxShape.circle,
                  border: Border.all(color: EllaColors.mangoDark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ghost Button ─────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GhostButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFE0D0B8),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: EllaColors.neutralSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Transcript Row ───────────────────────────────────────────────────────────

class _TranscriptRow extends StatelessWidget {
  final _TranscriptEntry entry;
  const _TranscriptRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: entry.isElla
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              entry.isElla ? 'ZOE' : 'YOU',
              style: GoogleFonts.inconsolata(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: entry.isElla ? EllaColors.skyDark : EllaColors.mangoDark,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: entry.isElla
                  ? EllaColors.skyLightest
                  : EllaColors.mangoLightest,
              borderRadius: entry.isElla
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(4),
                    ),
              border: Border.all(
                color: entry.isElla
                    ? EllaColors.skyLight
                    : EllaColors.mangoLight,
                width: 1.5,
              ),
            ),
            child: Text(
              entry.text,
              style: entry.isElla
                  ? GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.skyDark,
                      height: 1.4,
                    )
                  : GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralPrimary,
                      height: 1.4,
                    ),
            ),
          ),
          if (entry.correction != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: EllaColors.mangoLightest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EllaColors.mangoLight, width: 1),
              ),
              child: Text(
                entry.correction!,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.mangoDark,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
