// First-run onboarding — Figma "Onboarding" frames (Intro + Name → User says
// name → Zoe asks age → User says age → Zoe congrats → First Sprout →
// Spotlight → revert to garden).
//
// Shown by RootGate (app.dart) for an unplaced student who hasn't onboarded
// yet. A chat-style conversation on the shared garden background: Zoe asks the
// child's name and age (each prompt is spoken aloud via TTS, with a replay
// sound button on the bubble), the child types a reply in the composer, then
// Zoe congratulates and the First Sprout garden intro plays: the sprout grows
// out of its tile under a spotlight, Zoe nudges toward the first conversation,
// and after 5s without interaction the spotlight fades away leaving the sprout
// in the garden. "Let's Talk" calls onboardingProvider.complete(), which flips
// the gate so RootGate reactively swaps to PlacementIntroScreen — no manual nav.
//
// The mascot mirrors the interaction state: speaking while TTS plays, thinking
// while Zoe "processes" a reply, listening otherwise.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../services/audio_service.dart';
import '../../../services/stt_tts_service.dart';
import '../widgets/ella_primary_button.dart';
import '../widgets/garden_sky_background.dart';
import '../widgets/placement_garden_header.dart';
import '../widgets/spotlight_overlay.dart';
import '../widgets/zoe_mascot.dart';
import '../chat_bubble.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';

// First-sprout garden art (Figma placement-garden frame).
const String _kFirstPlant = 'assets/garden/plants/placement-plant-young.svg';
const String _kFenceSegment = 'assets/garden/plants/fence-segment 8.svg';
const String _kWildflowers = 'assets/garden/plants/wildflowers 2.svg';

// Zoe's spotlight nudge (Figma copy) — shared by the flow state and the bubble.
const String _kNudgeText =
    'Look, your first plant 🌱\nEvery conversation grows something new here.';

enum _Step { name, age, congrats, garden }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.name;
  ZoeMascotMode _mascot = ZoeMascotMode.listening;

  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  /// The child's reply bubble currently on screen (exactly as typed).
  String? _userReply;
  String? _fieldError;

  String _name = '';
  int? _age;

  bool _busy = false; // guards the send button during step transitions
  bool _submitting = false;

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating — same pattern as GardenScreen's audio handle).
  late final TtsInterface _tts;
  int _highlightStart = -1;
  int _highlightEnd = -1;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  // ── Zoe's script (Figma copy) ───────────────────────────────────────────────

  static const String _introText =
      "Hi, I'm Zoe 👋\nI'll help your English grow and want to know you "
      'better. What is your name?';
  String get _ageText =>
      'Great, $_name. Next, I wanted to know what is your age?';
  String get _congratsText =>
      "Alright $_name. Your garden is ready! Let's plant something";

  String get _zoeText => switch (_step) {
        _Step.name => _introText,
        _Step.age => _ageText,
        _Step.congrats => _congratsText,
        _Step.garden => _kNudgeText,
      };

  /// True when this launch resumed with a cached name/age (the child closed or
  /// backgrounded the app on the first-sprout garden) — start settled on the
  /// garden, without replaying the grow/spotlight intro or re-asking anything.
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    
    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
    // saveProfile persisted the name/age the moment they were collected; when
    // they're already cached, resume straight on the first-sprout garden.
    final cached = ref.read(onboardingProvider).valueOrNull;
    final cachedName = cached?.name;
    final cachedAge = cached?.age;
    if (cachedName != null && cachedName.isNotEmpty && cachedAge != null) {
      _name = cachedName;
      _age = cachedAge;
      _step = _Step.garden;
      _resumed = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _replyFocus.requestFocus();
      _speak(_introText);
    });
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _replyFocus.dispose();
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    // Cut Zoe off if the flow is left mid-utterance.
    _tts.stop().catchError((_) {});
    super.dispose();
  }

  // ── TTS + mascot state ──────────────────────────────────────────────────────

  /// Speaks [text] aloud, driving the mascot: speaking while the utterance
  /// plays (speak() awaits real completion), listening after. TTS failures are
  /// non-fatal — the bubble is on screen either way.
  Future<void> _speak(String text) async {
    final tts = ref.read(ttsProvider);
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() {
        _highlightStart = -1;
        _highlightEnd = -1;
        _mascot = ZoeMascotMode.speaking;
      });
      await tts.speak(text);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _mascot = ZoeMascotMode.listening;
        _highlightStart = -1;
        _highlightEnd = -1;
      });
    }
  }

  /// Sound-button replays: a no-op while TTS is already speaking, so a tap can
  /// never restart or stack the utterance.
  Future<void> _replay(String text) async {
    if (_tts.isSpeaking) return;
    await _speak(text);
  }

  // ── Reply parsing ───────────────────────────────────────────────────────────
  // The child may answer conversationally ("My name is Narendra", "I am 12
  // years old") — the bubble shows their words verbatim, while the stored
  // profile keeps just the name/age.

  static String _extractName(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'[.!?]+$'), '');
    final lower = t.toLowerCase();
    for (final prefix in ['my name is ', 'i am ', "i'm ", 'name is ']) {
      if (lower.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  static int? _extractAge(String raw) {
    final match = RegExp(r'\d{1,3}').firstMatch(raw);
    if (match == null) return null;
    final age = int.parse(match.group(0)!);
    return age > 0 ? age : null;
  }

  // ── Step transitions ────────────────────────────────────────────────────────

  Future<void> _onSend() async {
    if (_busy) return;
    final typed = _replyCtrl.text.trim();

    if (_step == _Step.name) {
      final name = _extractName(typed);
      if (name.isEmpty) {
        setState(() => _fieldError = 'Please tell me your name');
        return;
      }
      _name = name;
      await _advance(typed, next: _Step.age, prompt: _ageText);
      if (mounted) _replyFocus.requestFocus();
    } else if (_step == _Step.age) {
      final age = _extractAge(typed);
      if (age == null) {
        setState(() => _fieldError = 'Please tell me your age');
        return;
      }
      _age = age;
      _replyFocus.unfocus();
      // Persist name/age right away (done stays false) so closing the app on
      // the upcoming garden screen resumes there instead of re-asking.
      unawaited(
        ref.read(onboardingProvider.notifier).saveProfile(
              name: _name,
              age: age,
            ),
      );
      await _advance(typed, next: _Step.congrats, prompt: _congratsText);
      // Give the congrats line a beat, then plant the first sprout.
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _step = _Step.garden);
    }
  }

  /// Shows the child's reply, lets Zoe "think", then swaps to [next] and
  /// speaks [prompt] (awaiting utterance completion).
  Future<void> _advance(
    String reply, {
    required _Step next,
    required String prompt,
  }) async {
    setState(() {
      _busy = true;
      _fieldError = null;
      _userReply = reply;
      _mascot = ZoeMascotMode.thinking;
      _replyCtrl.clear();
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _step = next;
      _userReply = null;
      _busy = false;
    });
    await _speak(prompt);
  }

  Future<void> _onLetsTalk() async {
    if (_submitting) return;
    final age = _age;
    if (age == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(ttsProvider).stop();
    } catch (_) {}
    // complete() flips onboardingProvider → RootGate swaps to
    // PlacementIntroScreen.
    await ref
        .read(onboardingProvider.notifier)
        .complete(name: _name, age: age);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return GardenSkyBackground(
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _step == _Step.garden
              ? _GardenIntro(
                  key: const ValueKey('garden'),
                  name: _name,
                  mascotMode: _mascot,
                  reducedMotion: reducedMotion,
                  playIntro: !_resumed,
                  onNudge: () => _replay(_kNudgeText),
                  onLetsTalk: _onLetsTalk,
                )
              : _ChatStep(
                  key: const ValueKey('chat'),
                  zoeText: _zoeText,
                  userReply: _userReply,
                  mascotMode: _mascot,
                  reducedMotion: reducedMotion,
                  showComposer: _step != _Step.congrats,
                  controller: _replyCtrl,
                  focusNode: _replyFocus,
                  error: _fieldError,
                  sendEnabled: !_busy,
                  onSend: _onSend,
                  onReplay: () => _replay(_zoeText),
                  highlightStart: _highlightStart,
                  highlightEnd: _highlightEnd,
                ),
        ),
      ),
    );
  }
}

// ── Chat step (name / age / congrats) ─────────────────────────────────────────

class _ChatStep extends StatelessWidget {
  final String zoeText;
  final String? userReply;
  final ZoeMascotMode mascotMode;
  final bool reducedMotion;
  final bool showComposer;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool sendEnabled;
  final VoidCallback onSend;
  final VoidCallback onReplay;
  final int highlightStart;
  final int highlightEnd;

  const _ChatStep({
    super.key,
    required this.zoeText,
    required this.userReply,
    required this.mascotMode,
    required this.reducedMotion,
    required this.showComposer,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.sendEnabled,
    required this.onSend,
    required this.onReplay,
    this.highlightStart = -1,
    this.highlightEnd = -1,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZoeMascot(
                    mode: mascotMode,
                    size: mascotW,
                    reducedMotion: reducedMotion,
                  ),
                  const SizedBox(height: 16),
                  // Cross-fade when Zoe's line changes (name → age → congrats).
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _ZoeBubble(
                      key: ValueKey(zoeText),
                      text: zoeText,
                      onReplay: onReplay,
                      highlightStart: highlightStart,
                      highlightEnd: highlightEnd,
                    ),
                  ),
                  if (userReply != null) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _UserBubble(text: userReply!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (error != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: EllaTextStyles.bodySmall.copyWith(
                    color: EllaColors.error,
                  ),
                ),
              ),
            ),
          ],
          if (showComposer)
            _ReplyComposer(
              controller: controller,
              focusNode: focusNode,
              enabled: sendEnabled,
              onSend: onSend,
            ),
        ],
      ),
    );
  }
}

// Zoe's bubble — same visual language as the placement/conversation _ZoeBubble
// (surface fill, info border 2.5, squared top-left tail, bodySemibold text),
// plus the berry sound button hanging off the top-right corner (replays the
// prompt aloud), per the Figma name/age frames.
class _ZoeBubble extends StatelessWidget {
  final String text;
  final VoidCallback onReplay;
  final int highlightStart;
  final int highlightEnd;

  const _ZoeBubble({
    super.key,
    required this.text,
    required this.onReplay,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 24, 16),
          decoration: BoxDecoration(
            color: EllaColors.surface,
            // Squared top-left "tail" pointing at Zoe; blue info border —
            // identical to the conversation screen's Zoe bubble.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: EllaColors.info, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: TypewriterText(
            text: text,
            animate: false,
            highlightStart: highlightStart,
            highlightEnd: highlightEnd,
            style: EllaTextStyles.bodySemibold,
            highlightStyle: EllaTextStyles.bodySemibold.copyWith(
              color: const Color(0xFFE91E63),
            ),
          ),
        ),
        Positioned(
          top: -14,
          right: -6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: withTapClick(onReplay),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: EllaColors.berryMain,
                shape: BoxShape.circle,
                border: Border.all(color: EllaColors.berryDeep, width: 2),
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                size: 18,
                color: EllaColors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// The child's reply, echoed verbatim — same visual language as the
// conversation screen's _StudentBubble (pale pink fill, berryDark border 2.5,
// squared bottom-right tail, bodySemibold text).
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  // Student bubble fill from speaking.svg (paler than berryLight) — matches
  // conversation_view.dart's _studentFill.
  static const Color _fill = Color(0xFFFFF2F7);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: EllaColors.berryDark, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(text, style: EllaTextStyles.bodySemibold),
    );
  }
}

// "Type your reply…" composer — rounded field + round berry arrow send button
// (same flat/stamp treatment as the home-screen buttons via EllaIconButton).
class _ReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            style: EllaTextStyles.bodyBase,
            decoration: InputDecoration(
              hintText: 'Type your reply...',
              hintStyle: EllaTextStyles.bodyBase.copyWith(
                color: EllaColors.textTertiary,
              ),
              filled: true,
              fillColor: EllaColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: EllaColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: EllaColors.berryDark,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        EllaIconButton(
          icon: Icons.arrow_forward_rounded,
          size: 54,
          onTap: enabled ? onSend : null,
        ),
      ],
    );
  }
}

// ── First Sprout garden intro (grow → spotlight → settled) ────────────────────

enum _GardenPhase { grow, spotlight, settled }

class _GardenIntro extends StatefulWidget {
  final String name;
  final ZoeMascotMode mascotMode;
  final bool reducedMotion;

  /// False when resuming a relaunch with cached name/age: the garden starts
  /// settled (sprout already grown, no spotlight/nudge replay).
  final bool playIntro;

  /// Speaks the nudge line (spotlight reveal + the header sound button).
  final VoidCallback onNudge;
  final VoidCallback onLetsTalk;

  const _GardenIntro({
    super.key,
    required this.name,
    required this.mascotMode,
    required this.reducedMotion,
    required this.playIntro,
    required this.onNudge,
    required this.onLetsTalk,
  });

  @override
  State<_GardenIntro> createState() => _GardenIntroState();
}

class _GardenIntroState extends State<_GardenIntro> {
  late _GardenPhase _phase =
      widget.playIntro ? _GardenPhase.grow : _GardenPhase.settled;
  Timer? _spotlightTimer;
  Timer? _revertTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.playIntro) return;
    // Let the sprout grow out of its tile, then reveal the spotlight + nudge.
    _spotlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _phase = _GardenPhase.spotlight);
      widget.onNudge();
      // Figma: revert to the plain garden after 5 seconds if no interaction —
      // the spotlight and nudge fade away, the sprout stays.
      _revertTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _phase = _GardenPhase.settled);
      });
    });
  }

  @override
  void dispose() {
    _spotlightTimer?.cancel();
    _revertTimer?.cancel();
    super.dispose();
  }

  bool get _spotlightOn => _phase == _GardenPhase.spotlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim the surroundings while the spotlight is on; fades out on revert.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _spotlightOn ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: const SpotlightOverlay(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              PlacementGardenHeader(
                name: widget.name,
                // No-op at the root route; kept for the Figma header layout.
                onBack: () => Navigator.of(context).maybePop(),
                onSound: widget.onNudge,
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Plot (ellipse + tile + plant + fence) truly centred in
                    // the space between header and CTA, per the Figma frame.
                    Positioned.fill(
                      child: Center(
                        child: _GrowingSprout(animate: widget.playIntro),
                      ),
                    ),
                    // Wildflower accents dotted on the meadow (Figma).
                    Positioned(
                      right: 2,
                      top: 60,
                      child: SvgPicture.asset(_kWildflowers, width: 34),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 24,
                      child: SvgPicture.asset(_kWildflowers, width: 30),
                    ),
                    // Nudge — small Zoe over her bubble, only during the
                    // spotlight, pinned above the plot.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: AnimatedOpacity(
                        opacity: _spotlightOn ? 1 : 0,
                        duration: const Duration(milliseconds: 600),
                        child: IgnorePointer(
                          ignoring: !_spotlightOn,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ZoeMascot(
                                  mode: widget.mascotMode,
                                  size: 64,
                                  reducedMotion: widget.reducedMotion,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _NudgeBubble(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom "Let's Talk" — small Zoe beside the compact CTA pill
              // (Figma), shown once the sprout has grown; stays after the
              // spotlight fades.
              AnimatedOpacity(
                opacity: _phase == _GardenPhase.grow ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: IgnorePointer(
                  ignoring: _phase == _GardenPhase.grow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ZoeMascot(
                        mode: widget.mascotMode,
                        size: 44,
                        reducedMotion: widget.reducedMotion,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 164,
                        child: EllaPrimaryButton(
                          label: "Let's Talk",
                          height: 44,
                          leading: SvgPicture.asset(
                            _kVoiceIcon,
                            width: 17,
                            height: 17,
                            colorFilter: const ColorFilter.mode(
                              EllaColors.onPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          onTap: widget.onLetsTalk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NudgeBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EllaColors.info, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(_kNudgeText, style: EllaTextStyles.bodySemibold),
    );
  }
}

// The plot: turf ellipse + tile + the placement young plant popping up from its
// base (easeOutBack) over a warm spotlight glow, with the fence run beneath —
// matching the Figma placement-garden frame. When [animate] is false (resumed
// relaunch) everything starts at its final, fully-grown state.
class _GrowingSprout extends StatefulWidget {
  final bool animate;

  const _GrowingSprout({required this.animate});

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
    if (widget.animate) {
      _grow.forward();
    } else {
      _grow.value = 1.0;
    }
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
      width: 320,
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Warm spotlight glow pooled around the tile.
          Positioned(
            bottom: 20,
            child: FadeTransition(
              opacity: _scale,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x8CFFF3D4),
                      Color(0x40FFF3D4),
                      Color(0x00FFF3D4),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 52,
            child: SvgPicture.asset(
              'assets/gardent-view/Ellipse.svg',
              width: 300,
            ),
          ),
          // Bush resting inside the turf ellipse (front-left, garden-screen).
          Positioned(
            bottom: 78,
            left: 42,
            child: SvgPicture.asset('assets/gardent-view/bush.svg', width: 30),
          ),
          Positioned(
            bottom: 90,
            child: SvgPicture.asset(
              'assets/gardent-view/tiles-turf.svg',
              width: 150,
            ),
          ),
          // The young plant pops up from its base as it grows in.
          Positioned(
            bottom: 138,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(_kFirstPlant, height: 140),
            ),
          ),
          // Fence run below the plot (Figma placement garden).
          const Positioned(left: 0, right: 0, bottom: 0, child: _FenceRow()),
        ],
      ),
    );
  }
}

// A run of fence segments with a gentle stagger, per the Figma frame.
class _FenceRow extends StatelessWidget {
  const _FenceRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Transform.translate(
            offset: Offset(0, i.isEven ? 0 : 7),
            child: SvgPicture.asset(_kFenceSegment, width: 38),
          ),
      ],
    );
  }
}

