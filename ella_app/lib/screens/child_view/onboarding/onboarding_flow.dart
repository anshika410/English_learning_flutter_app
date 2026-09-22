// Complete Onboarding & Placement Flow matching exact Figma specification & Placement V2 API:
// Name -> Age -> Welcome -> Q1 (Level) -> Q2 (What to Improve) -> Q3 (Introduce Yourself) -> Level Indication (Result) -> Main Home.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app.dart' show placementCacheProvider;
import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../core/offline_alert_popup.dart';
import '../../../models/placement.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/piper_download_provider.dart';
import '../../../providers/service_providers.dart';
import '../../../services/audio_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/stt_tts_service.dart';
import '../../../services/native_tts_service.dart';
import '../widgets/ella_primary_button.dart';
import '../widgets/hear_again_button.dart';
import '../widgets/home_scene_background.dart';
import '../widgets/zoe_mascot.dart';

import 'widgets/placement_top_progress_bar.dart';
import 'widgets/placement_level_radio_group.dart';
import 'widgets/placement_voice_dock.dart';
import 'widgets/placement_result_card.dart';

enum _Step {
  name,
  age,
  welcome,
  levelQ1,
  voiceQ2,
  voiceQ3,
  result,
}

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.name;
  ZoeMascotMode _mascot = ZoeMascotMode.listening;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();

  String _name = '';
  int? _age;
  int? _selectedLevelIndex;

  String _q2VoiceResponse = '';
  String _q3VoiceResponse = '';
  String? _validationError;

  bool _isListening = false;
  bool _busy = false;
  bool _evaluatingPlacement = false;
  PlacementTurnResult? _placementTurnResult;

  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  // ── Prompts ───────────────────────────────────────────────────────────────

  static const String _namePrompt =
      "Hi, I'm Ella.\nWhat should I call you?";
  String get _agePrompt =>
      "Thanks, $_name.\nHow old are you?";

  static const String _levelPrompt =
      "Pick one that suits you.";

  static const String _q2Prompt =
      "Tell me a little about why you want to learn English.";
  static const String _q3Prompt =
      "Tell me something about yourself?";

  String get _currentPrompt => switch (_step) {
    _Step.name => _namePrompt,
    _Step.age => _agePrompt,
    _Step.welcome => "Nice to Meet You, $_name",
    _Step.levelQ1 => _levelPrompt,
    _Step.voiceQ2 => _q2Prompt,
    _Step.voiceQ3 => _q3Prompt,
    _Step.result => "Hooray! That's a fantastic start.",
  };

  late final TtsInterface _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    AnalyticsService.logOnboardingStarted();

    // Keep screen awake while user is speaking/recording/listening during Placement
    WakelockPlus.enable();

    // Start background download of Piper voice model so it is ready for post-placement session conversation
    ref.read(piperDownloadProvider.notifier).startIfNeeded();

    _subscribeToActiveTts();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _restorePlacementState();
      if (!mounted) return;
      _speak(_currentPrompt);
    });
  }

  @override
  void dispose() {
    // Release screen wakelock on leaving placement flow
    WakelockPlus.disable();

    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _nameFocusNode.dispose();
    _ageFocusNode.dispose();
    _tts.stop().catchError((_) {});
    super.dispose();
  }

  Future<void> _restorePlacementState() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingState = ref.read(onboardingProvider).valueOrNull;
    final cachedName = prefs.getString('ella_api_user_name') ?? onboardingState?.name;
    final cachedAge = prefs.getInt('ella_api_user_age') ?? onboardingState?.age;

    if (cachedName != null && cachedName.isNotEmpty) {
      _name = cachedName;
      _nameCtrl.text = cachedName;
    }
    if (cachedAge != null && cachedAge > 0) {
      _age = cachedAge;
      _ageCtrl.text = cachedAge.toString();
    }

    // If Name & Age are already saved/known: always resume Placement from the first question (_Step.levelQ1)
    if (_name.isNotEmpty && _age != null && _age! > 0) {
      if (mounted) {
        setState(() {
          _step = _Step.levelQ1;
        });
      }
    }
  }

  Future<void> _saveCurrentStep(_Step step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ella_placement_step', step.name);
    } catch (_) {}
  }

  void _subscribeToActiveTts() {
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    final activeTts = _tts;
    _ttsProgressSub = activeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() => _speaking = true);
      }
    });
    _ttsDoneSub = activeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _mascot = ZoeMascotMode.listening;
        });
      }
    });
  }

  // ── Speech Output (Placement strictly uses Native TTS; Piper is used post-placement) ────

  Future<void> _speak(String text) async {
    _subscribeToActiveTts();
    final tts = _tts;
    try {
      await tts.stop();
      if (!mounted) return;
      await tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
    if (mounted) {
      setState(() {
        _speaking = false;
        _mascot = ZoeMascotMode.listening;
      });
    }
  }

  Future<void> _replayCurrentPrompt() async {
    if (_speaking) return;
    await _speak(_currentPrompt);
  }

  // ── Voice Input (STT) ──────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    final stt = ref.read(sttProvider);
    if (_isListening) {
      await stt.stopListening();
      setState(() => _isListening = false);
      _advanceVoiceQuestion();
    } else {
      await _tts.stop();
      setState(() {
        _isListening = true;
        _validationError = null;
      });
      await stt.initialize();
      await stt.startListening(
        onPartial: (partial) {
          if (mounted) {
            setState(() {
              if (_step == _Step.voiceQ2) _q2VoiceResponse = partial;
              if (_step == _Step.voiceQ3) _q3VoiceResponse = partial;
            });
          }
        },
        onFinal: (finalText) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (_step == _Step.voiceQ2) _q2VoiceResponse = finalText;
              if (_step == _Step.voiceQ3) _q3VoiceResponse = finalText;
            });
            _advanceVoiceQuestion();
          }
        },
      );
    }
  }

  void _advanceVoiceQuestion() {
    final currentResponse = _step == _Step.voiceQ2 ? _q2VoiceResponse : _q3VoiceResponse;
    if (currentResponse.trim().isEmpty) {
      setState(() {
        _validationError = "I didn't catch that. Let's try again.";
      });
      return;
    }

    setState(() {
      _validationError = null;
    });

    if (_step == _Step.voiceQ2) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _step == _Step.voiceQ2) {
          setState(() => _step = _Step.voiceQ3);
          _saveCurrentStep(_Step.voiceQ3);
          _speak(_q3Prompt);
        }
      });
    } else if (_step == _Step.voiceQ3) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _step == _Step.voiceQ3) {
          _showResultScreen();
        }
      });
    }
  }

  // ── Step Navigation & Back Button ──────────────────────────────────────────

  void _onBack() {
    _tts.stop().catchError((_) {});
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _validationError = null);

    switch (_step) {
      case _Step.name:
        Navigator.of(context).maybePop();
      case _Step.age:
        setState(() => _step = _Step.name);
        _speak(_namePrompt);
      case _Step.welcome:
        setState(() => _step = _Step.age);
        _speak(_agePrompt);
        _focusAgeInput();
      case _Step.levelQ1:
        setState(() => _step = _Step.welcome);
        _speak("Nice to Meet You, $_name");
      case _Step.voiceQ2:
        setState(() => _step = _Step.levelQ1);
        _speak(_levelPrompt);
      case _Step.voiceQ3:
        setState(() => _step = _Step.voiceQ2);
        _speak(_q2Prompt);
      case _Step.result:
        setState(() => _step = _Step.voiceQ3);
        _speak(_q3Prompt);
    }
  }

  void _focusAgeInput() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted && _step == _Step.age) {
        FocusScope.of(context).requestFocus(_ageFocusNode);
      }
    });
  }

  void _onNameSubmitted() {
    final raw = _nameCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _validationError = "Please enter your name");
      return;
    }

    if (RegExp(r'[^A-Za-z\s\-\.]').hasMatch(raw)) {
      setState(() => _validationError = "Names should only contain letters");
      return;
    }

    var cleaned = raw.replaceAll(RegExp(r'[^A-Za-z\s\-\.]'), '').trim();
    if (cleaned.isEmpty) {
      setState(() => _validationError = "Names should only contain letters");
      return;
    }

    cleaned = cleaned.split(RegExp(r'\s+')).first;
    cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _name = cleaned;
      _validationError = null;
      _step = _Step.age;
    });
    _speak(_agePrompt);
    _focusAgeInput();
  }

  void _onAgeSubmitted() {
    final raw = _ageCtrl.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final parsedAge = int.tryParse(raw);
    if (parsedAge == null || parsedAge < 1 || parsedAge > 120) {
      setState(() => _validationError = "Please enter a valid age (e.g. 10)");
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _age = parsedAge;
      _validationError = null;
      _step = _Step.welcome;
    });

    ref.read(onboardingProvider.notifier).saveProfile(name: _name, age: parsedAge);
    _speak("Nice to Meet You, $_name");
  }

  void _onWelcomeContinue() {
    setState(() => _step = _Step.levelQ1);
    _saveCurrentStep(_Step.levelQ1);
    _speak(_levelPrompt);
  }

  void _onLevelQ1Continue() {
    if (_selectedLevelIndex == null) return;
    setState(() => _step = _Step.voiceQ2);
    _saveCurrentStep(_Step.voiceQ2);
    _speak(_q2Prompt);
  }

  Future<void> _showResultScreen() async {
    setState(() {
      _step = _Step.result;
      _evaluatingPlacement = true;
    });
    _saveCurrentStep(_Step.result);

    // Execute Placement V2 API call
    final selfReportedLevel = _selectedLevelIndex != null &&
            _selectedLevelIndex! < PlacementLevelRadioGroup.options.length
        ? PlacementLevelRadioGroup.options[_selectedLevelIndex!]
        : 'I can have short conversations';

    final userQ2Text = _q2VoiceResponse.trim();
    final userQ3Text = _q3VoiceResponse.trim();

    final messages = <Map<String, String>>[
      {
        'role': 'assistant',
        'content': 'What do you want to improve in your English?',
      },
      {
        'role': 'user',
        'content': userQ2Text,
      },
      {
        'role': 'assistant',
        'content': 'Tell me something about yourself?',
      },
      {
        'role': 'user',
        'content': userQ3Text,
      },
    ];

    try {
      final api = ref.read(ellaApiServiceProvider);
      final result = await api.placementTurn(
        messages: messages,
        name: _name,
        age: _age ?? 12,
        selfReportedLevel: selfReportedLevel,
      );
      if (mounted) {
        setState(() {
          _placementTurnResult = result;
          _evaluatingPlacement = false;
        });
        _speak("Hooray! That's a fantastic start.");
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _evaluatingPlacement = false;
        });
        _speak("Hooray! That's a fantastic start.");
      }
    }
  }

  Future<void> _onStartLearningEnglish() async {
    if (_busy) return;
    setState(() => _busy = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ella_placement_step');
    await prefs.setBool('ella_api_placement_done', true);

    final ageVal = _age ?? 10;
    final api = ref.read(ellaApiServiceProvider);

    try {
      await api.updateProfile(name: _name, age: ageVal);
    } catch (_) {}

    await ref.read(onboardingProvider.notifier).complete(name: _name, age: ageVal);

    ref.invalidate(placementCacheProvider);
    await ref.read(chatProvider.notifier).refreshAfterPlacement();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  String _getEvaluatedLevelTitle() {
    if (_placementTurnResult?.levelName != null &&
        _placementTurnResult!.levelName!.isNotEmpty) {
      return _placementTurnResult!.levelName!;
    }
    final idx = _selectedLevelIndex ?? 0;
    return switch (idx) {
      0 => 'Lv. 1 First Words',
      1 => 'Lv. 2 Simple Phrases',
      2 => 'Lv. 3 Everyday Talk',
      3 => 'Lv. 4 Expressing Ideas',
      _ => 'Lv. 5 Fluent Conversations',
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final size = MediaQuery.of(context).size;

    // Responsive horizontal padding (16px to 24px)
    final outerHPad = (size.width * 0.05).clamp(16.0, 24.0);

    // Responsive vertical gaps based on screen height
    final spaceAfterMascot = (size.height * 0.02).clamp(10.0, 18.0);
    final spaceAfterPrompt = (size.height * 0.024).clamp(12.0, 24.0);
    final subtitlePadding = (size.width * 0.06).clamp(16.0, 28.0);

    // Responsive mascot size scaling cleanly across height & width (Compact mascot for questions/name/age)
    final mascotW = switch (_step) {
      _Step.welcome => (size.height * 0.16).clamp(95.0, 120.0),
      _Step.result => (size.height * 0.14).clamp(90.0, 110.0),
      _ => (size.height * 0.11).clamp(68.0, 88.0),
    };

    final double? progress = switch (_step) {
      _Step.levelQ1 => 1 / 3,
      _Step.voiceQ2 => 2 / 3,
      _Step.voiceQ3 => 1.0,
      _ => null,
    };

    return HomeSceneBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: EdgeInsets.fromLTRB(outerHPad, 8, outerHPad, 16),
              child: Column(
                children: [
                  // Header Row: Top-left Circular Back Button ABOVE Progress Bar (Strictly Left Aligned)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CircleBackButton(onTap: _onBack),
                        if (progress != null) ...[
                          const SizedBox(height: 10),
                          PlacementTopProgressBar(progress: progress),
                          SizedBox(height: (size.height * 0.016).clamp(10.0, 16.0)),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              "This will help us get to know you and\npersonalise your learning",
                              textAlign: TextAlign.center,
                              style: EllaFonts.body(
                                const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.6,
                                  letterSpacing: 0,
                                  color: EllaColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: (size.height * 0.012).clamp(6.0, 12.0)),

                  // Main Content (Shifted slightly above center so last component rests near visual center)
                  Expanded(
                    child: Align(
                      alignment: const Alignment(0, -0.35),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_step != _Step.welcome && _step != _Step.result)
                              const SizedBox(height: 4),

                            if (_step != _Step.result) ...[
                              ZoeMascot(
                                mode: _mascot,
                                size: mascotW,
                                reducedMotion: reducedMotion,
                              ),
                              if (_step != _Step.welcome) ...[
                                const SizedBox(height: 8),
                                HearAgainButton(
                                  onTap: _speaking ? null : _replayCurrentPrompt,
                                  disabled: _speaking,
                                ),
                              ],
                              SizedBox(height: spaceAfterMascot),
                            ],

                          // Step 1: Name Input Screen (23px heading font size)
                          if (_step == _Step.name) ...[
                            _FigmaHeadingPrompt(
                              text: _namePrompt,
                              onReplay: _replayCurrentPrompt,
                              isSpeaking: _speaking,
                              headingFontSize: 23,
                            ),
                            SizedBox(height: spaceAfterPrompt),
                            _TextInputPill(
                              key: const ValueKey('name_input_pill'),
                              controller: _nameCtrl,
                              focusNode: _nameFocusNode,
                              hintText: 'Type Your Name...',
                              keyboardType: TextInputType.name,
                              maxLength: 30,
                              onChanged: (_) {
                                if (_validationError != null) {
                                  setState(() => _validationError = null);
                                }
                              },
                              onSubmitted: (_) => _onNameSubmitted(),
                            ),
                            if (_validationError != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _validationError!,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    color: EllaColors.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],

                          // Step 2: Age Input Screen (23px heading font size, strictly numeric keyboard)
                          if (_step == _Step.age) ...[
                            _FigmaHeadingPrompt(
                              text: _agePrompt,
                              onReplay: _replayCurrentPrompt,
                              isSpeaking: _speaking,
                              headingFontSize: 23,
                            ),
                            SizedBox(height: spaceAfterPrompt),
                            _TextInputPill(
                              key: const ValueKey('age_input_pill'),
                              controller: _ageCtrl,
                              focusNode: _ageFocusNode,
                              hintText: 'Type Your Age...',
                              keyboardType: const TextInputType.numberWithOptions(
                                signed: false,
                                decimal: false,
                              ),
                              autofocus: true,
                              maxLength: 3,
                              onChanged: (_) {
                                if (_validationError != null) {
                                  setState(() => _validationError = null);
                                }
                              },
                              onSubmitted: (_) => _onAgeSubmitted(),
                            ),
                            if (_validationError != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _validationError!,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    color: EllaColors.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],

                          // Step 3: Welcome Screen (Centered on screen with slightly reduced text component spacing)
                          if (_step == _Step.welcome) ...[
                            SizedBox(height: (size.height * 0.02).clamp(10.0, 16.0)),
                            Text(
                              "Nice to Meet You, $_name",
                              textAlign: TextAlign.center,
                              style: EllaFonts.bricolage(
                                TextStyle(
                                  fontSize: (size.width * 0.058).clamp(20.0, 24.0),
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: EllaColors.ink,
                                ),
                              ),
                            ),
                            SizedBox(height: (size.height * 0.02).clamp(12.0, 18.0)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: subtitlePadding),
                              child: Text(
                                "Let’s get to know you &\npersonalise your learning.",
                                textAlign: TextAlign.center,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.6,
                                    letterSpacing: 0,
                                    color: EllaColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Step 4: Placement Q1 (English Level Selection)
                          if (_step == _Step.levelQ1) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _FigmaHeadingPrompt(
                                text: _levelPrompt,
                                onReplay: _replayCurrentPrompt,
                                isSpeaking: _speaking,
                                headingFontSize: 20,
                              ),
                            ),
                            SizedBox(height: (size.height * 0.02).clamp(12.0, 20.0)),
                            PlacementLevelRadioGroup(
                              selectedIndex: _selectedLevelIndex,
                              onSelect: (idx) {
                                setState(() => _selectedLevelIndex = idx);
                              },
                            ),
                          ],

                          // Step 5: Placement Q2 (Tell me a little about why you want to learn English.)
                          if (_step == _Step.voiceQ2) ...[
                            const SizedBox(height: 6),
                            const _VoiceSpeechBubbleCard(
                              text: "Tell me a little about why\nyou want to learn English.",
                            ),
                            SizedBox(height: (size.height * 0.018).clamp(10.0, 16.0)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: subtitlePadding),
                              child: Text(
                                'Tell us what you hope to achieve.',
                                textAlign: TextAlign.center,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                    color: EllaColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: spaceAfterPrompt),
                          ],

                          // Step 6: Placement Q3 (Tell me something about yourself? 😎)
                          if (_step == _Step.voiceQ3) ...[
                            const SizedBox(height: 6),
                            const _VoiceSpeechBubbleCard(
                              text: "Tell me something about\nyourself? 😎",
                            ),
                            SizedBox(height: (size.height * 0.018).clamp(10.0, 16.0)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: subtitlePadding),
                              child: Text(
                                'Speak as long as you like.',
                                textAlign: TextAlign.center,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                    color: EllaColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: spaceAfterPrompt),
                          ],

                          // Step 7: Placement Level Indication Result Screen
                          if (_step == _Step.result) ...[
                            PlacementResultCard(
                              name: _name,
                              levelTitle: _getEvaluatedLevelTitle(),
                              isLoading: _evaluatingPlacement,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                  const SizedBox(height: 10),

                  // Bottom CTA Buttons (Fixed at bottom of screen with caret right icon & spacing)
                  if (_step == _Step.name)
                    EllaPrimaryButton(
                      key: const ValueKey('chat-reply-send'),
                      label: 'Continue',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: EllaColors.onPrimary,
                      ),
                      height: (size.height * 0.065).clamp(48.0, 52.0),
                      onTap: _onNameSubmitted,
                    ),

                  if (_step == _Step.age)
                    EllaPrimaryButton(
                      key: const ValueKey('chat-reply-send'),
                      label: 'Continue',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: EllaColors.onPrimary,
                      ),
                      height: (size.height * 0.065).clamp(48.0, 52.0),
                      onTap: _onAgeSubmitted,
                    ),

                  if (_step == _Step.welcome)
                    EllaPrimaryButton(
                      label: 'Get Started',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: EllaColors.onPrimary,
                      ),
                      height: (size.height * 0.065).clamp(48.0, 52.0),
                      onTap: _onWelcomeContinue,
                    ),

                  if (_step == _Step.levelQ1)
                    EllaPrimaryButton(
                      label: 'Continue',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: EllaColors.onPrimary,
                      ),
                      height: (size.height * 0.065).clamp(48.0, 52.0),
                      onTap: _selectedLevelIndex != null ? _onLevelQ1Continue : null,
                    ),

                  if (_step == _Step.result)
                    EllaPrimaryButton(
                      label: 'Start learning',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: EllaColors.onPrimary,
                      ),
                      height: (size.height * 0.065).clamp(48.0, 52.0),
                      onTap: _evaluatingPlacement ? null : _onStartLearningEnglish,
                    ),

                  // Q2 & Q3 use Voice Dock ONLY — NO Continue button!
                  if (_step == _Step.voiceQ2 || _step == _Step.voiceQ3) ...[
                    if (_validationError != null) ...[
                      _SpeechErrorBanner(message: _validationError!),
                      const SizedBox(height: 12),
                    ],
                    PlacementVoiceDock(
                      isListening: _isListening,
                      hasResponse: _step == _Step.voiceQ2
                          ? _q2VoiceResponse.isNotEmpty
                          : _q3VoiceResponse.isNotEmpty,
                      onMicTap: _toggleMic,
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top-Left Circular Back Button Widget ──────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F6EE),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF185E35), width: 2.79),
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_back_rounded,
            size: 14,
            color: Color(0xFF185E35),
          ),
        ),
      ),
    );
  }
}

// ── Figma Voice Question Speech Bubble Box (Q2 & Q3) ─────────────────────────

class _VoiceSpeechBubbleCard extends StatelessWidget {
  final String text;

  const _VoiceSpeechBubbleCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        side: const BorderSide(color: EllaColors.info, width: 2.5),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: EllaFonts.bricolage(
          const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: EllaColors.ink,
          ),
        ),
      ),
    );
  }
}

// ── Figma Heading Prompt & Hear Again Button ────────────────────────────────

class _FigmaHeadingPrompt extends StatelessWidget {
  final String text;
  final VoidCallback onReplay;
  final bool isSpeaking;
  final double headingFontSize;

  const _FigmaHeadingPrompt({
    required this.text,
    required this.onReplay,
    this.isSpeaking = false,
    this.headingFontSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final responsiveFontSize = (size.width * 0.058).clamp(19.0, headingFontSize);

    final headingStyle = EllaFonts.bricolage(
      TextStyle(
        fontFamily: 'Amulya',
        fontSize: responsiveFontSize,
        fontWeight: FontWeight.w700,
        height: 1.5,
        letterSpacing: 0.001,
        color: EllaColors.ink,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
      ],
    );
  }
}

// ── Text Input Pill Widget (Name & Age Input) ─────────────────────────────────

class _TextInputPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextInputType keyboardType;
  final bool autofocus;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _TextInputPill({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD4E5DB), width: 1.8),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        autofocus: autofocus,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: EllaFonts.body(
          const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: EllaColors.ink,
          ),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: EllaFonts.body(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: EllaColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}

// ── Speech Error Banner (Matches Session Screen Design) ─────────────────────

class _SpeechErrorBanner extends StatelessWidget {
  final String message;

  const _SpeechErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: EllaColors.greenMain.withValues(alpha: 0.38),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: EllaFonts.body(
          const TextStyle(
            color: EllaColors.greenDeep,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
