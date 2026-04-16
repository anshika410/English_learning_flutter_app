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
  final String levelLabel;
  final String description;

  const _LevelConfig({
    required this.cardBg,
    required this.borderColor,
    required this.greeting,
    required this.emoji,
    required this.levelLabel,
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
        levelLabel: 'First Words',
        description:
            'You understood the conversation and gave it a real go.\nNext up: putting words together more often.',
      );
    case 'B1':
      return _LevelConfig(
        cardBg: EllaColors.limeLightest,
        borderColor: EllaColors.limeMain,
        greeting: 'Solid, $name.',
        emoji: '⚡',
        levelLabel: 'Speaking Freely',
        description:
            'You held the conversation well and expressed most of what you wanted to say.\nNext up: sharper grammar and more range.',
      );
    case 'B2':
      return _LevelConfig(
        cardBg: EllaColors.roseLightest,
        borderColor: EllaColors.roseMain,
        greeting: 'Impressive, $name.',
        emoji: '🔥',
        levelLabel: 'Almost Fluent',
        description:
            'You spoke clearly and handled the conversation with confidence.\nNext up: making it feel second nature.',
      );
    case 'C1':
      return _LevelConfig(
        cardBg: EllaColors.grapeLightest,
        borderColor: EllaColors.grapeMain,
        greeting: 'Exceptional, $name.',
        emoji: '🏆',
        levelLabel: 'Fluent',
        description:
            'You expressed yourself precisely and kept up with every turn.\nNext up: nuance and depth.',
      );
    case 'A2':
    default:
      return _LevelConfig(
        cardBg: EllaColors.mangoLightest,
        borderColor: EllaColors.mangoMain,
        greeting: 'Great work, $name!',
        emoji: '🎉',
        levelLabel: 'Finding My Voice',
        description:
            'You got your point across when it mattered.\nNext up: sounding more natural as you go.',
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
                    if (city != null || age != null) ...[
                      Text(
                        'A MOMENT FROM YOUR CONVERSATION',
                        style: GoogleFonts.inconsolata(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: EllaColors.neutralMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (city != null) _InfoChip(icon: '📍', label: city!),
                          if (age != null) _InfoChip(icon: '🎂', label: age!),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHERE YOU STAND',
                  style: GoogleFonts.inconsolata(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: EllaColors.neutralMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.levelLabel,
                  style: const TextStyle(
                    fontFamily: 'Chillax',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EllaColors.neutralPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  config.description,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: EllaColors.neutralPrimary,
                    height: 1.5,
                  ),
                ),
              ],
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
              fontWeight: FontWeight.w500,
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
    return Text(
      highlight,
      style: GoogleFonts.baloo2(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: EllaColors.neutralSecondary,
        height: 1.5,
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
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
