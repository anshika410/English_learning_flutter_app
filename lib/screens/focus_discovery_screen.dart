import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/focus_settings.dart';
import '../providers/chat_provider.dart';
import '../theme/ella_theme.dart';
import 'home_screen.dart';

// ─── Focus Discovery Screen ───────────────────────────────────────────────────
// Shown once after the first non-empty conversation (partial or full session).
// Lets B1+ users customise Zoe's coaching focus before picking a new topic.

class FocusDiscoveryScreen extends StatefulWidget {
  const FocusDiscoveryScreen({super.key});

  @override
  State<FocusDiscoveryScreen> createState() => _FocusDiscoveryScreenState();
}

class _FocusDiscoveryScreenState extends State<FocusDiscoveryScreen> {
  // ── Mascot animation ──────────────────────────────────────────────────────
  static const _mascotSequence = [
    _MascotStep('assets/mascot-animations/listening.webp', 4000),
    _MascotStep('assets/mascot-animations/juggling.webp', 3000),
  ];

  int _mascotIndex = 0;
  Timer? _mascotTimer;

  // ── Local focus selections (pre-populated from provider) ──────────────────
  late GrammarFocus _grammar;
  late VocabFocus _vocab;
  late FluencyFocus _fluency;

  @override
  void initState() {
    super.initState();
    final settings = context.read<ChatProvider>().focusSettings;
    _grammar = settings.grammar;
    _vocab = settings.vocabulary;
    _fluency = settings.fluency;
    _scheduleMascot();
  }

  @override
  void dispose() {
    _mascotTimer?.cancel();
    super.dispose();
  }

  void _scheduleMascot() {
    _mascotTimer?.cancel();
    _mascotTimer = Timer(
      Duration(milliseconds: _mascotSequence[_mascotIndex].holdMs),
      () {
        if (!mounted) return;
        setState(() {
          _mascotIndex = (_mascotIndex + 1) % _mascotSequence.length;
        });
        _scheduleMascot();
      },
    );
  }

  void _letsGo() {
    context.read<ChatProvider>().updateFocusSettings(
          FocusSettings(
            grammar: _grammar,
            vocabulary: _vocab,
            fluency: _fluency,
          ),
        );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    // ── Mascot ──────────────────────────────────────────────
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EllaColors.zoeMintLight,
                        boxShadow: [
                          BoxShadow(
                            color: EllaColors.neutralMuted.withValues(alpha: 0.35),
                            offset: const Offset(0, 5),
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            offset: const Offset(0, 3),
                            blurRadius: 12,
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
                            _mascotSequence[_mascotIndex].asset,
                            key: ValueKey<int>(_mascotIndex),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Eyebrow ─────────────────────────────────────────────
                    Text(
                      'FIRST CONVERSATION DONE!',
                      style: const TextStyle(
                        fontFamily: 'Inconsolata',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.mangoMain,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Headline ────────────────────────────────────────────
                    Text(
                      'Did you know you can\ntell Zoe what to focus on?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Chillax',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.neutralPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Profile hint ────────────────────────────────────────
                    Text(
                      '(You can change these anytime in the profile later)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.neutralSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Subtext ─────────────────────────────────────────────
                    Text(
                      "These are Zoe's default settings for your level.\nChange anything, or just tap Let's go to keep them.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.neutralMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Grammar ─────────────────────────────────────────────
                    _FocusBlock<GrammarFocus>(
                      icon: Icons.spellcheck_rounded,
                      iconColor: EllaColors.skyMain,
                      title: 'Grammar',
                      subtitle: 'How Zoe handles your grammar errors',
                      values: GrammarFocus.values,
                      selected: _grammar,
                      onChanged: (v) => setState(() => _grammar = v),
                    ),
                    const SizedBox(height: 24),

                    // ── Vocabulary ──────────────────────────────────────────
                    _FocusBlock<VocabFocus>(
                      icon: Icons.auto_stories_rounded,
                      iconColor: EllaColors.limeMain,
                      title: 'Vocabulary',
                      subtitle: 'How actively Zoe suggests new words',
                      values: VocabFocus.values,
                      selected: _vocab,
                      onChanged: (v) => setState(() => _vocab = v),
                    ),
                    const SizedBox(height: 24),

                    // ── Fluency ─────────────────────────────────────────────
                    _FocusBlock<FluencyFocus>(
                      icon: Icons.speed_rounded,
                      iconColor: EllaColors.mangoMain,
                      title: 'Fluency',
                      subtitle: 'How Zoe tracks your pace and fillers',
                      values: FluencyFocus.values,
                      selected: _fluency,
                      onChanged: (v) => setState(() => _fluency = v),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Let's go button ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: _LetsGoButton(onTap: _letsGo),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic Focus Block ──────────────────────────────────────────────────────

class _FocusBlock<T extends Enum> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  const _FocusBlock({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  String _labelFor(T v) {
    if (v is GrammarFocus) return v.label;
    if (v is VocabFocus) return v.label;
    if (v is FluencyFocus) return v.label;
    return v.name;
  }

  String _descriptionFor(T v) {
    if (v is GrammarFocus) return v.description;
    if (v is VocabFocus) return v.description;
    if (v is FluencyFocus) return v.description;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.neutralPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Chip row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: values.map((v) {
              final isSelected = v == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? EllaColors.mangoLightest : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected ? EllaColors.mangoDark : EllaColors.neutralBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? EllaColors.mangoDark : EllaColors.neutralBorder,
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      _labelFor(v),
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? EllaColors.mangoDeepest
                            : EllaColors.neutralSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Selected description
        Text(
          _descriptionFor(selected),
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Let's Go Button ──────────────────────────────────────────────────────────

class _LetsGoButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LetsGoButton({required this.onTap});

  @override
  State<_LetsGoButton> createState() => _LetsGoButtonState();
}

class _LetsGoButtonState extends State<_LetsGoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: EllaColors.mangoMain,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: Offset(0, _pressed ? 1 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            "Let's go →",
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mascot step ──────────────────────────────────────────────────────────────

class _MascotStep {
  final String asset;
  final int holdMs;
  const _MascotStep(this.asset, this.holdMs);
}
