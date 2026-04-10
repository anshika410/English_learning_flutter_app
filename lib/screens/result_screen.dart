import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'home_screen.dart';

// Per-level visual + copy configuration
class _LevelConfig {
  final Color cardBg;
  final Color borderColor;
  final String greeting;
  final String emoji;
  final String description;

  const _LevelConfig({
    required this.cardBg,
    required this.borderColor,
    required this.greeting,
    required this.emoji,
    required this.description,
  });
}

_LevelConfig _configForLevel(String level, String name) {
  switch (level.toUpperCase()) {
    case 'A1':
      return _LevelConfig(
        cardBg: EllaColors.skyLightest,
        borderColor: EllaColors.skyMain,
        greeting: 'Good start, $name!',
        emoji: '🌱',
        description:
            'You can understand simple words and short sentences.\nNext: you\'ll start putting those words together to say what you mean.',
      );
    case 'B1':
      return _LevelConfig(
        cardBg: EllaColors.limeLightest,
        borderColor: EllaColors.limeMain,
        greeting: 'Solid, $name.',
        emoji: '⚡',
        description:
            'You can hold a real conversation and express most of what you want to say.\nNext: you\'ll sharpen the edges — grammar, vocabulary range, and fluency under pressure.',
      );
    case 'B2':
      return _LevelConfig(
        cardBg: EllaColors.roseLightest,
        borderColor: EllaColors.roseMain,
        greeting: 'Impressive, $name.',
        emoji: '🔥',
        description:
            'You can speak clearly and in detail on a wide range of topics without much effort.\nNext: you\'ll close the gap between speaking well and speaking like it\'s second nature.',
      );
    case 'C1':
      return _LevelConfig(
        cardBg: EllaColors.grapeLightest,
        borderColor: EllaColors.grapeMain,
        greeting: 'Exceptional, $name.',
        emoji: '🏆',
        description:
            'You can express yourself fluently and precisely, even in complex or unfamiliar situations.\nNext: you\'ll refine nuance, tone, and the kind of depth that makes people listen.',
      );
    case 'A2':
    default:
      return _LevelConfig(
        cardBg: EllaColors.mangoLightest,
        borderColor: EllaColors.mangoMain,
        greeting: 'Great work, $name!',
        emoji: '🎉',
        description:
            'You can get your meaning across in everyday situations, even if it\'s not always smooth.\nNext: you\'ll work on saying things more naturally and with more confidence.',
      );
  }
}

class ResultScreen extends StatelessWidget {
  final String level;
  final String levelName;
  final String highlight;
  final String name;
  final String? city;
  final String? age;

  const ResultScreen({
    super.key,
    required this.level,
    required this.levelName,
    this.highlight =
        'You expressed yourself clearly and stayed engaged throughout the check.',
    this.name = 'there',
    this.city,
    this.age,
  });

  void _goToMainApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _configForLevel(level, name);

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: _ResultZoeMascot(),
                    ),
                    const SizedBox(height: 20),

                    // ── Level card ─────────────────────────────────────
                    _LevelCard(
                      config: config,
                      level: level,
                      levelName: levelName,
                    ),
                    const SizedBox(height: 20),

                    // ── Context chips ──────────────────────────────────
                    if (city != null || age != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (city != null) _InfoChip(icon: '📍', label: city!),
                          if (age != null) _InfoChip(icon: '🎂', label: age!),
                        ],
                      ),
                    if (city != null || age != null) const SizedBox(height: 20),

                    // ── From your conversation ─────────────────────────
                    _ConversationHighlight(highlight: highlight),
                  ],
                ),
              ),
            ),

            // ── CTA button pinned at bottom ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: EllaPrimaryButton(
                label: "Let's Start Learning",
                onTap: () => _goToMainApp(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Level Card ──────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final _LevelConfig config;
  final String level;
  final String levelName;

  const _LevelCard({
    required this.config,
    required this.level,
    required this.levelName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: config.borderColor,
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + greeting ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji icon in white circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: config.borderColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    config.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.greeting,
                      style: const TextStyle(
                        fontFamily: 'Chillax',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.neutralPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Here\'s where you stand.',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.neutralSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Description sub-box ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              config.description,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: EllaColors.neutralBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: EllaColors.neutralBorder,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
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

// ─── Conversation Highlight ───────────────────────────────────────────────────

class _ConversationHighlight extends StatelessWidget {
  final String highlight;

  const _ConversationHighlight({required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EllaColors.neutralSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EllaColors.neutralBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: EllaColors.neutralMuted,
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FROM YOUR CONVERSATION',
            style: GoogleFonts.inconsolata(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: EllaColors.neutralMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlight,
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: EllaColors.neutralPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultZoeMascot extends StatelessWidget {
  const _ResultZoeMascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EllaColors.zoeMintLight,
        boxShadow: [
          BoxShadow(
            color: EllaColors.neutralMuted.withValues(alpha: 0.40),
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
        child: Image.asset(
          'assets/mascot-animations/listening.webp',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
