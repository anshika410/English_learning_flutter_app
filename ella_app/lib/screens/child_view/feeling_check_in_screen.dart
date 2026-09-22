import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/conversation_feedback.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/stt_tts_service.dart';
import 'widgets/floating_leaf.dart';
import 'widgets/home_scene_background.dart';
import 'widgets/mascot_glow.dart';
import 'widgets/zoe_mascot.dart';

const String _acknowledgement = 'Thanks for telling me how you feel!';

/// Key prefix for the locally-stored feeling answer, namespaced per session
/// so a later backend-sync PR can walk stored keys by session id.
const String _feelingPrefsKeyPrefix = 'conversation_feeling.';

class FeelingCheckInScreen extends ConsumerStatefulWidget {
  final ConversationEndContext endContext;
  final VoidCallback onComplete;
  final String? studentName;

  const FeelingCheckInScreen({
    super.key,
    required this.endContext,
    required this.onComplete,
    this.studentName,
  });

  @override
  ConsumerState<FeelingCheckInScreen> createState() =>
      _FeelingCheckInScreenState();
}

class _FeelingCheckInScreenState extends ConsumerState<FeelingCheckInScreen> {
  late final TtsInterface _tts;
  ConversationFeeling? _selected;
  bool _speaking = false;
  bool _completed = false;
  bool _showAcknowledgement = false;
  int _speechToken = 0;

  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  String get _firstName {
    final supplied = widget.studentName?.trim();
    if (supplied != null && supplied.isNotEmpty) {
      return supplied.split(RegExp(r'\s+')).first;
    }
    return ref.read(onboardingProvider).valueOrNull?.firstName ?? 'there';
  }

  String get _greeting =>
      _firstName == 'there' ? 'Hey there!' : 'Hey $_firstName!';

  String get _spokenPrompt => '$_greeting How did the conversation feel?';

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _ttsProgressSub = _tts.progressStream.listen((_) {
      if (mounted) setState(() => _speaking = true);
    });
    _ttsDoneSub = _tts.doneStream.listen((_) {
      if (mounted) setState(() => _speaking = false);
    });
    AnalyticsService.logScreenView('Conversation Feeling Check-In');
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _selected == null) _speakPrompt();
    });
  }

  Future<void> _speakPrompt() async {
    final token = ++_speechToken;
    try {
      await _tts.speak(_spokenPrompt);
    } catch (_) {
      // The visual question remains fully usable when TTS is unavailable.
    } finally {
      if (mounted && token == _speechToken && _selected == null) {
        setState(() => _speaking = false);
      }
    }
  }

  Future<void> _speakAcknowledgement() async {
    try {
      await _tts.speak(_acknowledgement);
    } catch (_) {
      // Visual pacing below doesn't depend on TTS succeeding.
    }
  }

  Future<void> _select(ConversationFeeling feeling) async {
    if (_selected != null || _completed) return;

    ++_speechToken; // Invalidates completion from an interrupted prompt.
    setState(() {
      _selected = feeling;
      _speaking = false;
    });

    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) return;

    unawaited(_persistFeeling(feeling));
    unawaited(
      AnalyticsService.logConversationFeelingSubmitted(
        feeling: feeling,
        conversationNumber: widget.endContext.conversationNumber,
        endReason: widget.endContext.reason,
      ),
    );

    final token = ++_speechToken;

    // Hold the selected emoji highlighted alone for a beat before moving on.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted || token != _speechToken) return;

    setState(() {
      _showAcknowledgement = true;
    });

    // Wait for Zoe to actually finish saying the line before starting the
    // post-speech hold — do not race navigation against TTS playback.
    await _speakAcknowledgement();
    if (!mounted || _completed || token != _speechToken) return;
    setState(() => _speaking = false);

    // Let the acknowledgement bubble sit on screen after speech ends.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted || _completed || token != _speechToken) return;

    _completed = true;
    widget.onComplete();
  }

  Future<void> _persistFeeling(ConversationFeeling feeling) async {
    final sessionId = widget.endContext.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_feelingPrefsKeyPrefix$sessionId',
        jsonEncode({
          'feeling': feeling.apiValue,
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (error) {
      debugPrint('Conversation feeling save failed: $error');
    }
  }

  @override
  void dispose() {
    ++_speechToken;
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: HomeSceneBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0.0, constraints.maxHeight - 42),
                  ),
                  child: Column(
                    children: [
                      _MascotStage(
                        selected: _selected,
                        speaking: _speaking,
                        reducedMotion: reducedMotion,
                      ),
                      const SizedBox(height: 8),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          child: _showAcknowledgement
                              ? const Padding(
                                  key: ValueKey('feeling-acknowledgement-stage'),
                                  padding: EdgeInsets.only(top: 6),
                                  child: _AcknowledgementBubble(),
                                )
                              : Column(
                                  key: const ValueKey('feeling-question-stage'),
                                  children: [
                                    Text(
                                      _greeting,
                                      key: const ValueKey('feeling-greeting'),
                                      textAlign: TextAlign.center,
                                      style: EllaTextStyles.headline.copyWith(
                                        color: EllaColors.greenDeep,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const _PlantDivider(),
                                    const SizedBox(height: 18),
                                    Text(
                                      'How did this conversation feel?',
                                      key: const ValueKey('feeling-question'),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: EllaTextStyles.titleMedium.copyWith(
                                        color: EllaColors.greenDeep,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _FeelingChoices(
                                      selected: _selected,
                                      onSelect: _select,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotStage extends StatelessWidget {
  final ConversationFeeling? selected;
  final bool speaking;
  final bool reducedMotion;

  const _MascotStage({
    required this.selected,
    required this.speaking,
    required this.reducedMotion,
  });

  ZoeMascotMode get _mode {
    if (speaking) return ZoeMascotMode.speaking;
    return switch (selected) {
      ConversationFeeling.great => ZoeMascotMode.joyful,
      ConversationFeeling.okay => ZoeMascotMode.affirming,
      ConversationFeeling.notGreat => ZoeMascotMode.concerned,
      null => ZoeMascotMode.idle,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('feeling-mascot-stage'),
      height: 258,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 4,
            left: 8,
            child: SvgPicture.asset(
              'assets/gardent-view/clouds-weather.svg',
              key: const ValueKey('feeling-cloud-left'),
              width: 56,
            ),
          ),
          Positioned(
            top: 4,
            right: 8,
            child: SvgPicture.asset(
              'assets/gardent-view/clouds-weather.svg',
              key: const ValueKey('feeling-cloud-right'),
              width: 56,
            ),
          ),
          MascotGlow(size: 280, reducedMotion: reducedMotion),
          Positioned(
            left: 34,
            bottom: 28,
            child: FloatingLeaf(
              asset: 'assets/decorations/leaf-2.svg',
              size: 17,
              phaseMs: 900,
              reducedMotion: reducedMotion,
            ),
          ),
          Positioned(
            right: 34,
            bottom: 42,
            child: FloatingLeaf(
              asset: 'assets/decorations/leaf-3.svg',
              size: 19,
              phaseMs: 1400,
              reducedMotion: reducedMotion,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.34),
            child: _ReactionMascot(
              feeling: selected,
              mode: _mode,
              reducedMotion: reducedMotion,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionMascot extends StatefulWidget {
  final ConversationFeeling? feeling;
  final ZoeMascotMode mode;
  final bool reducedMotion;

  const _ReactionMascot({
    required this.feeling,
    required this.mode,
    required this.reducedMotion,
  });

  @override
  State<_ReactionMascot> createState() => _ReactionMascotState();
}

class _ReactionMascotState extends State<_ReactionMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didUpdateWidget(covariant _ReactionMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feeling != widget.feeling && widget.feeling != null) {
      if (widget.reducedMotion) {
        _reaction.value = 1;
      } else {
        _reaction.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const ValueKey('feeling-zoe-reaction'),
      animation: _reaction,
      builder: (context, child) {
        final eased = Curves.easeOutBack.transform(_reaction.value);
        final matrix = Matrix4.identity();
        var dy = 0.0;
        var scale = 1.0;

        switch (widget.feeling) {
          case ConversationFeeling.great:
            final lift = widget.reducedMotion
                ? 1.0
                : math.sin(math.pi * _reaction.value);
            dy = -12 * lift;
            scale = 1 + 0.07 * lift;
            break;
          case ConversationFeeling.okay:
            final nod = widget.reducedMotion
                ? 1.0
                : math.sin(math.pi * 2 * _reaction.value);
            matrix.setEntry(3, 2, 0.0012);
            matrix.rotateX(0.07 * nod);
            break;
          case ConversationFeeling.notGreat:
            matrix.setEntry(3, 2, 0.0018);
            matrix.rotateX(-0.20 * eased.clamp(0.0, 1.0));
            break;
          case null:
            break;
        }

        matrix.translateByDouble(0.0, dy, 0.0, 1.0);
        matrix.scaleByDouble(scale, scale, scale, 1.0);
        return Transform(
          key: ValueKey(
            'feeling-zoe-transform-${widget.feeling?.apiValue ?? 'idle'}',
          ),
          alignment: Alignment.bottomCenter,
          transform: matrix,
          child: child,
        );
      },
      child: ZoeMascot(
        mode: widget.mode,
        size: 174,
        reducedMotion: widget.reducedMotion,
      ),
    );
  }
}

class _AcknowledgementBubble extends StatelessWidget {
  const _AcknowledgementBubble();

  static const String _text = 'Thanks for telling me how you feel!';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('feeling-acknowledgement-bubble'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: EllaColors.info, width: 3),
      ),
      child: Text(
        _text,
        textAlign: TextAlign.center,
        style: EllaTextStyles.bodySemiboldLarge.copyWith(
          color: EllaColors.greenDeep,
        ),
      ),
    );
  }
}

class _PlantDivider extends StatelessWidget {
  const _PlantDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: EllaColors.borderStrong, thickness: 1.5),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SvgPicture.asset(
            'assets/homescreen/new/Plant.svg',
            width: 22,
            height: 22,
          ),
        ),
        const Expanded(
          child: Divider(color: EllaColors.borderStrong, thickness: 1.5),
        ),
      ],
    );
  }
}

class _FeelingChoices extends StatelessWidget {
  final ConversationFeeling? selected;
  final ValueChanged<ConversationFeeling> onSelect;

  const _FeelingChoices({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feeling in ConversationFeeling.values)
          Expanded(
            child: _FeelingChoice(
              feeling: feeling,
              selected: selected,
              onTap: () => onSelect(feeling),
            ),
          ),
      ],
    );
  }
}

class _FeelingChoice extends StatelessWidget {
  final ConversationFeeling feeling;
  final ConversationFeeling? selected;
  final VoidCallback onTap;

  const _FeelingChoice({
    required this.feeling,
    required this.selected,
    required this.onTap,
  });

  String get _label => switch (feeling) {
    ConversationFeeling.great => 'Great',
    ConversationFeeling.okay => 'Okay',
    ConversationFeeling.notGreat => 'Not Great',
  };

  String get _asset => switch (feeling) {
    ConversationFeeling.great => 'assets/feedback/great.png',
    ConversationFeeling.okay => 'assets/feedback/okay.png',
    ConversationFeeling.notGreat => 'assets/feedback/not-great.png',
  };

  Color get _labelColor => switch (feeling) {
    ConversationFeeling.great => EllaColors.greenDeep,
    ConversationFeeling.okay => EllaColors.textSecondary,
    ConversationFeeling.notGreat => EllaColors.errorDark,
  };

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    final isSelected = selected == feeling;
    final enabled = !hasSelection;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: '$_label conversation feeling',
      child: GestureDetector(
        key: ValueKey('feeling-choice-${feeling.apiValue}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: hasSelection && !isSelected ? 0.34 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: isSelected ? 1.06 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 110,
                    child: Image.asset(
                      _asset,
                      key: ValueKey('feeling-image-${feeling.apiValue}'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: EllaTextStyles.bodySemibold.copyWith(
                      color: _labelColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
