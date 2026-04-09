import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'home_screen.dart';

// ─── Mock transcript data ─────────────────────────────────────────────────────

class _TranscriptEntry {
  final bool isElla;
  final String text;
  final String? correction;
  _TranscriptEntry(this.isElla, this.text, {this.correction});
}

final List<_TranscriptEntry> _mockTranscript = [
  _TranscriptEntry(true, "Hey! Let's talk about daily routine. What time do you usually wake up?"),
  _TranscriptEntry(false, "I usually wake up at 7 in the morning.",
      correction: 'Great use of "usually"! ✓'),
  _TranscriptEntry(true, "Nice! And what do you do first thing in the morning?"),
  _TranscriptEntry(false, "I eated breakfast and then check my phone.",
      correction: 'Correction: "ate" not "eated" — past tense of eat is irregular.'),
  _TranscriptEntry(true, "I see! What helps you feel energised for the day?"),
  _TranscriptEntry(false, "Honestly, I also feel better after a short walk outside."),
];

// ─── EndScreen ────────────────────────────────────────────────────────────────

class EndScreen extends StatelessWidget {
  final String topic;
  final String durationLabel;

  const EndScreen({
    super.key,
    required this.topic,
    required this.durationLabel,
  });

  void _showTranscriptSheet(BuildContext context) {
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
              // Drag handle
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
              // Title
              Text(
                'Full Transcript',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.neutralPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Entries
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _mockTranscript.length,
                  itemBuilder: (ctx2, i) {
                    final entry = _mockTranscript[i];
                    return _TranscriptRow(entry: entry);
                  },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.limeLightest,
      // ── Pinned bottom buttons ────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Read Full Transcript" ghost button
              GestureDetector(
                onTap: () => _showTranscriptSheet(context),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                      bottomLeft: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: EllaColors.mangoMain,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: EllaColors.mangoDark,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Read Full Transcript',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.mangoMain,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // "Go to Home" primary button
              EllaPrimaryButton(
                label: 'Go to home',
                onTap: () => _goToHome(context),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Ella avatar (no circle/background) ────────────────────
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'images/ella-neutral.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Heading ───────────────────────────────────────────────
              Text(
                'Great conversation! ⭐',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.neutralPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$durationLabel · Finding My Voice · $topic',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.neutralSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // ── Best moment card ──────────────────────────────────────
              _EndCard(
                label: 'BEST MOMENT',
                labelColor: EllaColors.skyDark,
                bgColor: EllaColors.skyLightest,
                borderColor: EllaColors.skyLight,
                child: Text(
                  '"You used \'usually\' correctly 3 times — that\'s real progress!"',
                  style: GoogleFonts.kalam(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: EllaColors.skyDark,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── One thing to try card ─────────────────────────────────
              _EndCard(
                label: 'ONE THING TO TRY NEXT TIME',
                labelColor: EllaColors.neutralSecondary,
                bgColor: Colors.white,
                borderColor: EllaColors.neutralBorder,
                child: Text(
                  'Past tense with irregular verbs — "I ate" not "I eated"',
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.neutralPrimary,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── New words card ────────────────────────────────────────
              _EndCard(
                label: 'NEW WORD PLANTED 🌱',
                labelColor: EllaColors.limeDark,
                bgColor: EllaColors.limeLightest,
                borderColor: EllaColors.limeLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'usually',
                      style: GoogleFonts.fredoka(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: EllaColors.neutralPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'adverb · used correctly ×3',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.neutralSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Extra bottom padding so content doesn't hide behind bottom bar
              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── End Card ─────────────────────────────────────────────────────────────────

class _EndCard extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color bgColor;
  final Color borderColor;
  final Widget child;

  const _EndCard({
    required this.label,
    required this.labelColor,
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inconsolata(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
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
          // Speaker label
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              entry.isElla ? 'ELLA' : 'YOU',
              style: GoogleFonts.inconsolata(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: entry.isElla
                    ? EllaColors.skyDark
                    : EllaColors.mangoDark,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Bubble
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
                  ? GoogleFonts.kalam(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
          // Correction chip
          if (entry.correction != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: EllaColors.mangoLightest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EllaColors.mangoLight,
                  width: 1,
                ),
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
