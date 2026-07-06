// First-run onboarding — collects the child's name and age with text fields,
// then plays the "First Sprout" reveal before handing off to the placement Home.
//
// Shown by RootGate (app.dart) for an unplaced student who hasn't onboarded yet.
// Four internal steps on the shared garden background:
//   name → age → sprout (grows, auto-advances) → spotlight ("Let's Talk").
// The spotlight "Let's Talk" calls onboardingProvider.complete(), which flips the
// gate so RootGate reactively swaps to PlacementIntroScreen — no manual nav.
//
// Matches the Figma onboarding frames but replaces the audio conversation with
// text input, reusing GardenSkyBackground, ZoeMascot, SpeechBubble and the shared
// EllaPrimaryButton so it reads as the same app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../widgets/ella_primary_button.dart';
import '../widgets/garden_sky_background.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/zoe_mascot.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';

enum _Step { name, age, sprout, spotlight }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.name;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();

  String? _fieldError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  String get _name => _nameCtrl.text.trim();

  // ── Step transitions ────────────────────────────────────────────────────────

  void _onNameNext() {
    if (_name.isEmpty) {
      setState(() => _fieldError = 'Please enter your name');
      return;
    }
    _nameFocus.unfocus();
    setState(() {
      _fieldError = null;
      _step = _Step.age;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _ageFocus.requestFocus();
    });
  }

  void _onAgeNext() {
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null || age <= 0) {
      setState(() => _fieldError = 'Please enter your age');
      return;
    }
    _ageFocus.unfocus();
    setState(() {
      _fieldError = null;
      _step = _Step.sprout;
    });
    // Let the sprout grow in, then reveal the spotlight + CTA.
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _step = _Step.spotlight);
    });
  }

  Future<void> _onLetsTalk() async {
    if (_submitting) return;
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null) return;
    setState(() => _submitting = true);
    // complete() flips onboardingProvider → RootGate swaps to PlacementIntroScreen.
    await ref
        .read(onboardingProvider.notifier)
        .complete(name: _name, age: age);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GardenSkyBackground(
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: switch (_step) {
            _Step.name => _TextStep(
              key: const ValueKey('name'),
              question: 'What should I call you?',
              controller: _nameCtrl,
              focusNode: _nameFocus,
              hint: 'Your name',
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              inputAction: TextInputAction.next,
              error: _fieldError,
              onSubmitted: (_) => _onNameNext(),
              onNext: _onNameNext,
            ),
            _Step.age => _TextStep(
              key: const ValueKey('age'),
              question: 'How old are you, $_name?',
              controller: _ageCtrl,
              focusNode: _ageFocus,
              hint: 'Your age',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              inputAction: TextInputAction.done,
              error: _fieldError,
              onSubmitted: (_) => _onAgeNext(),
              onNext: _onAgeNext,
            ),
            _Step.sprout => const _SproutStep(
              key: ValueKey('sprout'),
              showSpotlight: false,
            ),
            _Step.spotlight => _SproutStep(
              key: const ValueKey('spotlight'),
              showSpotlight: true,
              onLetsTalk: _onLetsTalk,
            ),
          },
        ),
      ),
    );
  }
}

// ── Name / age step ───────────────────────────────────────────────────────────

class _TextStep extends StatelessWidget {
  final String question;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction inputAction;
  final String? error;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onNext;

  const _TextStep({
    super.key,
    required this.question,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    required this.inputAction,
    required this.error,
    required this.onSubmitted,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final mascotW = (MediaQuery.of(context).size.width * 0.35).clamp(
      128.0,
      168.0,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ZoeMascot(
                        mode: ZoeMascotMode.listening,
                        size: mascotW,
                        reducedMotion:
                            MediaQuery.of(context).disableAnimations,
                      ),
                      const SizedBox(height: 20),
                      SpeechBubble(text: question, showTail: true),
                      const SizedBox(height: 20),
                      _OnboardingField(
                        controller: controller,
                        focusNode: focusNode,
                        hint: hint,
                        keyboardType: keyboardType,
                        textCapitalization: textCapitalization,
                        inputFormatters: inputFormatters,
                        inputAction: inputAction,
                        hasError: error != null,
                        onSubmitted: onSubmitted,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            error!,
                            style: EllaTextStyles.bodySmall.copyWith(
                              color: EllaColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // "Next" — shared button style, pinned to the bottom-right.
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 148,
              child: EllaPrimaryButton(label: 'Next', onTap: onNext),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction inputAction;
  final bool hasError;
  final ValueChanged<String> onSubmitted;

  const _OnboardingField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.keyboardType,
    required this.textCapitalization,
    required this.inputFormatters,
    required this.inputAction,
    required this.hasError,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      textInputAction: inputAction,
      onSubmitted: onSubmitted,
      textAlign: TextAlign.center,
      // Same type style as Zoe's question above it, so the child's answer reads
      // as part of the same conversation (app Synonym family).
      style: EllaTextStyles.zoeVoice.copyWith(color: EllaColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: EllaTextStyles.zoeVoice.copyWith(
          color: EllaColors.textTertiary,
        ),
        filled: true,
        fillColor: EllaColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? EllaColors.error : EllaColors.border,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? EllaColors.error : EllaColors.berryDark,
            width: 2,
          ),
        ),
      ),
    );
  }
}

// ── First Sprout (with optional spotlight + CTA) ──────────────────────────────

class _SproutStep extends StatelessWidget {
  final bool showSpotlight;
  final VoidCallback? onLetsTalk;

  const _SproutStep({
    super.key,
    required this.showSpotlight,
    this.onLetsTalk,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim the surroundings and glow the sprout once revealed.
        if (showSpotlight) const IgnorePointer(child: _SpotlightOverlay()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              if (showSpotlight) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: ZoeMascot(
                    mode: ZoeMascotMode.speaking,
                    size: 84,
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                ),
                const SizedBox(height: 4),
                const SpeechBubble(
                  text: 'Look, your first plant 🌱\n'
                      'Every conversation grows something new here.',
                ),
              ],
              const Expanded(child: Center(child: _GrowingSprout())),
              if (showSpotlight)
                EllaPrimaryButton(
                  label: "Let's Talk",
                  height: 64,
                  leading: SvgPicture.asset(
                    _kVoiceIcon,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      EllaColors.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  onTap: onLetsTalk,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// The turf tile + sprout, scaling/fading in on first appearance (matches the
// _SwayingFlower composition on placement_complete_screen.dart).
class _GrowingSprout extends StatefulWidget {
  const _GrowingSprout();

  @override
  State<_GrowingSprout> createState() => _GrowingSproutState();
}

class _GrowingSproutState extends State<_GrowingSprout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _grow,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _grow.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _grow.value = 1.0;
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 14,
            child: SvgPicture.asset(
              'assets/gardent-view/Ellipse.svg',
              width: 220,
            ),
          ),
          Positioned(
            bottom: 44,
            child: SvgPicture.asset(
              'assets/gardent-view/tiles-turf.svg',
              width: 132,
            ),
          ),
          // The sprout pops up from its base as it grows in.
          Positioned(
            bottom: 78,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(
                'assets/gardent-view/plants-sprout.svg',
                height: 130,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Radial vignette: transparent over the sprout, easing to a translucent dark
// scrim at the edges — built fresh (no spotlight existed in the repo). Modelled
// on the sun RadialGradient in garden_sky_background.dart.
class _SpotlightOverlay extends StatelessWidget {
  const _SpotlightOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.25),
          radius: 0.85,
          colors: [
            Color(0x00185E35),
            Color(0x00185E35),
            Color(0x66123B23),
            Color(0x99102F1D),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
      ),
    );
  }
}
