// First-run onboarding — Figma "Onboarding" frames (Intro + Name -> User says
// name -> Zoe asks age -> User says age -> Zoe congrats). The post-age garden
// reveal is owned by PlacementGardenScreen so the placement garden art has one
// implementation.
//
// Shown by RootGate (app.dart) for an unplaced student who hasn't onboarded
// yet. A chat-style conversation on the shared garden background: Zoe asks the
// child's name and age (each prompt is spoken aloud via TTS, with a replay
// sound button on the bubble), the child types a reply in the composer, then
// Zoe congratulates and hands off to PlacementGardenScreen.onboardingReveal.
//
// The mascot mirrors the interaction state: speaking while TTS plays, thinking
// while Zoe "processes" a reply, listening otherwise.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import '../chat_bubble.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../core/offline_alert_popup.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../services/audio_service.dart';
import '../../../services/sounds.dart';
import '../../../services/analytics_service.dart';
import '../../../services/stt_tts_service.dart';
import '../placement_garden_screen.dart';
import '../widgets/chat_reply_composer.dart';
import '../widgets/garden_sky_background.dart';
import '../widgets/zoe_mascot.dart';

enum _Step { name, age, congrats }

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

  /// When a reply is invalid, Zoe re-asks in her own bubble using this text
  /// (overriding the step's default prompt) instead of a separate error line.
  String? _zoeOverride;

  String _name = '';
  int? _age;

  bool _busy = false; // guards the send button during step transitions

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating — same pattern as GardenScreen's audio handle).
  late final TtsInterface _tts;

  // ── Zoe's script (Figma copy) ───────────────────────────────────────────────

  static const String _introText =
      "Hi, I'm Zoe 👋\nI'll help your English grow and want to know you "
      'better. What is your name?';
  String get _ageText =>
      'Great, $_name. Next, I wanted to know what is your age?';
  String get _congratsText =>
      "Alright $_name. Your garden is ready! Let's plant something";

  String get _zoeText =>
      _zoeOverride ??
      switch (_step) {
        _Step.name => _introText,
        _Step.age => _ageText,
        _Step.congrats => _congratsText,
      };

  @override
  void initState() {
    super.initState();
    AnalyticsService.logOnboardingStarted();
    _tts = ref.read(ttsProvider);

    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _speaking = true;
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPlacementGarden(playReveal: false);
      });
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
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    _replyCtrl.dispose();
    _replyFocus.dispose();
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
    setState(() {
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() => _mascot = ZoeMascotMode.speaking);
      await tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
    if (mounted) {
      setState(() {
        _speaking = false;
        _mascot = ZoeMascotMode.listening;
      });
    }
  }

  /// Sound-button replays: while TTS is already speaking, tapping it stops
  /// (mutes) the speech. Otherwise, it replays the prompt.
  Future<void> _replay(String text) async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
          _mascot = ZoeMascotMode.listening;
        });
      }
    } else {
      await _speak(text);
    }
  }

  // ── Reply parsing ───────────────────────────────────────────────────────────
  // The child may answer conversationally ("My name is Narendra", "I am 12
  // years old") — the bubble shows their words verbatim, while the stored
  // profile keeps just the name/age.

  // A valid name is letters and spaces only, with apostrophes/hyphens allowed
  // inside (D'Souza, Mary-Jane). Digits or other symbols make it invalid.
  static final RegExp _nameOk = RegExp(
    r"^[A-Za-z][A-Za-z ]*(?:[’'\-][A-Za-z]+)*$",
  );

  /// Returns the cleaned, capitalised name, or null when the reply contains
  /// digits/symbols (so Zoe can re-ask). Conversational prefixes are stripped
  /// before the character check.
  static String? _extractName(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'[.!?]+$'), '');
    final lower = t.toLowerCase();
    for (final prefix in ['my name is ', 'i am ', "i'm ", 'name is ']) {
      if (lower.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }
    
    // Validate length and word count to prevent accepting full sentences
    if (t.length > 30) return null;
    if (t.split(RegExp(r'\s+')).length > 3) return null;
    
    if (t.isEmpty || !_nameOk.hasMatch(t)) return null;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Returns the age, or null when the reply isn't a plain number in a sane
  /// range. A trailing "years"/"years old" is tolerated; any other letter or
  /// symbol makes it invalid (so Zoe can re-ask).
  static int? _extractAge(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'[.!?]+$'), '');
    // Tolerate a conversational wrapper: "I am 12 years old" → "12".
    final lower = t.toLowerCase();
    for (final prefix in ['i am ', "i'm ", 'my age is ', 'age is ']) {
      if (lower.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }
    t = t.replaceAll(RegExp(r'\s*years?\s*old\s*$', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*years?\s*$', caseSensitive: false), '');
    if (!RegExp(r'^\d{1,3}$').hasMatch(t)) return null;
    final age = int.parse(t);
    return (age >= 1 && age <= 120) ? age : null;
  }

  // ── Step transitions ────────────────────────────────────────────────────────

  Future<void> _onSend() async {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      ref.read(audioProvider).playSfx(Sounds.error);
      OfflineAlertPopup.show(context);
      return;
    }

    if (_busy) return;
    final typed = _replyCtrl.text.trim();
    if (typed.isEmpty) return;

    if (_step == _Step.name) {
      final name = _extractName(typed);
      if (name == null) {
        // Re-ask as Zoe's next bubble (child's reply shown, Zoe asks again).
        await _reask(
          typed,
          "Hmm, I don't think that was your name. Can you tell me your name again?",
        );
        return;
      }
      _name = name;
      await _advance(typed, next: _Step.age, prompt: _ageText);
      if (mounted) _replyFocus.requestFocus();
    } else if (_step == _Step.age) {
      final age = _extractAge(typed);
      if (age == null) {
        await _reask(
          typed,
          "I couldn't get your correct age. Can you please share your age again?",
        );
        return;
      }
      _age = age;
      _replyFocus.unfocus();
      // Persist name/age right away (done stays false) so closing the app on
      // the upcoming garden screen resumes there instead of re-asking.
      unawaited(
        ref
            .read(onboardingProvider.notifier)
            .saveProfile(name: _name, age: age),
      );
      await _advance(typed, next: _Step.congrats, prompt: _congratsText);
      if (mounted) _openPlacementGarden();
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
      _userReply = reply;
      _mascot = ZoeMascotMode.thinking;
      _replyCtrl.clear();
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _step = next;
      _zoeOverride = null; // back to the step's default prompt
      _userReply = null;
      _busy = false;
    });
    await _speak(prompt);
  }

  /// Invalid reply: show the child's words as a bubble, let Zoe "think", then
  /// have her re-ask the same question ([prompt]) in her own bubble — no
  /// separate error line. Stays on the current step.
  Future<void> _reask(String reply, String prompt) async {
    setState(() {
      _busy = true;
      _userReply = reply;
      _mascot = ZoeMascotMode.thinking;
      _replyCtrl.clear();
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _zoeOverride = prompt;
      _userReply = null;
      _busy = false;
    });
    await _speak(prompt);
    if (mounted) _replyFocus.requestFocus();
  }

  void _openPlacementGarden({bool playReveal = true}) {
    final age = _age;
    if (age == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacementGardenScreen(
          mode: PlacementGardenMode.onboardingReveal,
          onboardingName: _name,
          onboardingAge: age,
          playReveal: playReveal,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return GardenSkyBackground(
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: _ChatStep(
            // Use step-specific key so widget rebuilds when step changes
            key: ValueKey('chat-$_step'),
            zoeText: _zoeText,
            userReply: _userReply,
            mascotMode: _mascot,
            reducedMotion: reducedMotion,
            showComposer: _step != _Step.congrats,
            controller: _replyCtrl,
            focusNode: _replyFocus,
            sendEnabled: !_busy,
            onSend: _onSend,
            onReplay: () => _replay(_zoeText),
            keyboardType: _step == _Step.age 
                ? TextInputType.number 
                : TextInputType.text,
            highlightStart: _highlightStart,
            highlightEnd: _highlightEnd,
            speaking: _speaking,
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
  final bool sendEnabled;
  final VoidCallback onSend;
  final VoidCallback onReplay;
  final TextInputType keyboardType;
  final int highlightStart;
  final int highlightEnd;
  final bool speaking;

  const _ChatStep({
    super.key,
    required this.zoeText,
    required this.userReply,
    required this.mascotMode,
    required this.reducedMotion,
    required this.showComposer,
    required this.controller,
    required this.focusNode,
    required this.sendEnabled,
    required this.onSend,
    required this.onReplay,
    this.keyboardType = TextInputType.text,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mascotW = (size.width * 0.35).clamp(128.0, 168.0);
    // Sky band above Zoe so she sits ~9% down the screen, matching Figma.
    final topGap = (size.height * 0.06).clamp(32.0, 72.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: topGap),
                  ZoeMascot(
                    mode: mascotMode,
                    size: mascotW,
                    reducedMotion: reducedMotion,
                  ),
                  const SizedBox(height: 16),
                  // Cross-fade when Zoe's line changes (name → age → congrats).
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: _ZoeBubble(
                      key: ValueKey(zoeText),
                      text: zoeText,
                      onReplay: onReplay,
                      highlightStart: highlightStart,
                      highlightEnd: highlightEnd,
                      speaking: speaking,
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
          if (showComposer)
            _ReplyComposer(
              controller: controller,
              focusNode: focusNode,
              enabled: sendEnabled,
              onSend: onSend,
              keyboardType: keyboardType,
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
  final bool speaking;

  const _ZoeBubble({
    super.key,
    required this.text,
    required this.onReplay,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 24, 16),
          decoration: ellaSmoothDecoration(
            color: EllaColors.surface,
            // Squared top-left "tail" pointing at Zoe; blue info border —
            // identical to the conversation screen's Zoe bubble.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            side: const BorderSide(color: EllaColors.info, width: 2.5),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: TypewriterText(
            text: text,
            style: EllaTextStyles.bodySemibold,
            highlightStart: highlightStart,
            highlightEnd: highlightEnd,
            animate: false,
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
                color: speaking ? EllaColors.berryDark : EllaColors.berryMain,
                shape: BoxShape.circle,
                border: Border.all(color: EllaColors.berryDeep, width: 2),
              ),
              child: Icon(
                speaking ? Icons.volume_off_rounded : Icons.volume_up_rounded,
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
      child: DottedBorder(
        color: const Color(0xFFE91E63),
        strokeWidth: 2.5,
        dashPattern: const [8, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(18),
        padding: const EdgeInsets.all(2),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SpokenTextFlow(
            text: text,
            style: EllaTextStyles.bodySemibold.copyWith(
              color: const Color(0xFF880E4F),
            ),
          ),
        ),
      ),
    );
  }
}

// "Type your reply…" composer — thin wrapper over the shared [ChatReplyComposer]
// (Figma node 441:26724) so the name/age step matches the conversation dock.
class _ReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;
  final TextInputType keyboardType;

  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return ChatReplyComposer(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onSend: onSend,
      keyboardType: keyboardType,
    );
  }
}
