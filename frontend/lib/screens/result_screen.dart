import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../theme/ella_responsive.dart';
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
        greeting: 'Great going, $name!',
        emoji: '🌱',
        levelLabel: 'First Words',
        description:
            'You understood the conversation and gave it a real go. Next Up: putting words together more often.',
      );
    case 'B1':
      return _LevelConfig(
        cardBg: EllaColors.limeLightest,
        borderColor: EllaColors.limeMain,
        greeting: 'Solid there, $name!',
        emoji: '⚡',
        levelLabel: 'Speaking Freely',
        description:
            'You held the conversation well and expressed most of what you wanted to say. Next Up: sharper grammar and more range.',
      );
    case 'B2':
      return _LevelConfig(
        cardBg: EllaColors.roseLightest,
        borderColor: EllaColors.roseMain,
        greeting: 'Impressive, $name!',
        emoji: '🔥',
        levelLabel: 'Almost Fluent',
        description:
            'You spoke clearly and handled the conversation with confidence. Next Up: making it feel second nature.',
      );
    case 'C1':
      return _LevelConfig(
        cardBg: EllaColors.grapeLightest,
        borderColor: EllaColors.grapeMain,
        greeting: 'Exceptional, $name!',
        emoji: '🏆',
        levelLabel: 'Fluent',
        description:
            'You expressed yourself precisely and kept up with every turn. Next Up: nuance and depth.',
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
            'You got your point across when it mattered. Next Up: sounding more natural as you go.',
      );
  }
}

class ResultScreen extends StatelessWidget {
  final String level;
  final String levelName;
  final String name;
  final String? city;
  final List<String>? interests;

  const ResultScreen({
    super.key,
    required this.level,
    required this.levelName,
    this.name = 'there',
    this.city,
    this.interests,
  });

  void _goToMainApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _configForLevel(level, name);
    final isWide = EllaResponsive.isWide(context);

    // Shared scrollable content children
    final scrollChildren = <Widget>[
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: const _ResultZoeMascot(),
        ),
      ),

      // ── Level card ─────────────────────────────────────────────────
      _LevelCard(config: config, level: level, levelName: levelName),
      const SizedBox(height: 20),

      // ── Context chips ───────────────────────────────────────────────
      if (interests != null && interests!.isNotEmpty) ...[
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
          children: interests!.map((interest) => _InfoChip(icon: '🎯', label: interest)).toList(),
        ),
        const SizedBox(height: 20),
      ],

      // ── On wide: button lives inside scroll, 48px below card ────────
      if (isWide) ...[
        const SizedBox(height: 28), // 20 already added above → total ~48px
        Center(
          child: EllaPrimaryButton(
            label: "Let's Start Learning",
            onTap: () => _goToMainApp(context),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ];

    final scrollView = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, isWide ? 0 : 40, 24, 24),
      child: isWide
          ? Center(
              child: SizedBox(
                width: 540,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: scrollChildren,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: scrollChildren,
            ),
    );

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: isWide
            ? Center(child: scrollView)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: scrollView),

                  // ── On mobile: button pinned at bottom ──────────────────────
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
                  'Here is where you stand',
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

class _ResultZoeMascot extends StatefulWidget {
  const _ResultZoeMascot();

  @override
  State<_ResultZoeMascot> createState() => _ResultZoeMascotState();
}

class _ResultZoeMascotState extends State<_ResultZoeMascot> {
  static const _sequence = [
    'assets/mascot-animations/listening.webp',
    'assets/mascot-animations/juggling.webp',
    'assets/mascot-animations/listening.webp',
    'assets/mascot-animations/bubblepop.webp',
    'assets/mascot-animations/listening.webp',
  ];

  int _index = 0;
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
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _sequence.length);
      _scheduleNext();
    });
  }

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Image.asset(
            _sequence[_index],
            key: ValueKey<int>(_index),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
