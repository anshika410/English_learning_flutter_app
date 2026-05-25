import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../services/native_stt_service.dart';
import '../services/backend_llm_service.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
import '../theme/ella_responsive.dart';
import '../widgets/waveform_icon.dart';
import '../widgets/offline_banner.dart';
import 'result_screen.dart';

// ─── Mascot State ─────────────────────────────────────────────────────────────

enum _MascotState { speaking, listening, thinking }

// ─── Data ─────────────────────────────────────────────────────────────────────

class _PlacementBubbleEntry {
  final String text;
  final bool isElla;
  final DateTime createdAt;

  const _PlacementBubbleEntry({
    required this.text,
    required this.isElla,
    required this.createdAt,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  static const String _mascotHeroTag = 'zoe-onboarding-placement-mascot';

  static const String _openingLine =
      'Hey, I am Zoe and I love a good conversation. What name should I call you with?';

  final NativeSttService _stt = NativeSttService();
  final TtsManager _tts = TtsManager();
  final BackendLlmService _llm = BackendLlmService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isKeyboardMode = false;
  bool _isListening = false;
  bool _isRecognizing = false;
  bool _isZoeSpeaking = false;
  bool _isCompleting = false;
  bool _isLlmThinking = false;
  String _currentTranscript = '';
  _MascotState _mascotState = _MascotState.speaking;
  bool _didPrecacheMascotImages = false;

  final List<_PlacementBubbleEntry> _history = [];

  // API message history: {role: 'user'|'model', content: '...'}
  final List<Map<String, String>> _apiMessages = [];

  // Extracted user info from LLM final assessment
  String? _userName;
  String? _userAge;
  String? _userLocation;

  @override
  void initState() {
    super.initState();
    // NativeSttService doesn't need explicit initialization
    _tts.initialize();
    Future.delayed(const Duration(milliseconds: 600), _playOpeningLine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheMascotImages) return;
    // Grab any name/age already set by OnboardingScreen
    final provider = context.read<ChatProvider>();
    _userName = provider.userName;
    _userAge = provider.userAge;
    precacheImage(
      const AssetImage('assets/mascot-animations/speaking.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/listening.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/regular-thinking.webp'),
      context,
    );
    _didPrecacheMascotImages = true;
  }

  @override
  void dispose() {
    _stt.dispose();
    _tts.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playOpeningLine() async {
    if (!mounted || _isCompleting) return;
    setState(() {
      _mascotState = _MascotState.thinking;
      _isZoeSpeaking = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isCompleting) return;

    setState(() {
      _history.add(
        _PlacementBubbleEntry(
          text: _openingLine,
          isElla: true,
          createdAt: DateTime.now(),
        ),
      );
      _mascotState = _MascotState.speaking;
      _isZoeSpeaking = true;
    });
    _scrollToBottom();

    // Add opening line to API history as a model message
    _apiMessages.add({'role': 'model', 'content': _openingLine});

    await _tts.speak(_openingLine).timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    if (!mounted) return;

    setState(() {
      _mascotState = _MascotState.listening;
      _isZoeSpeaking = false;
    });
  }

  void _handleUserResponse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isCompleting || _isZoeSpeaking) return;
    _textCtrl.clear();

    setState(() {
      _history.add(
        _PlacementBubbleEntry(
          text: trimmed,
          isElla: false,
          createdAt: DateTime.now(),
        ),
      );
      _isListening = false;
      _currentTranscript = '';
      _isKeyboardMode = false;
    });
    _textFocusNode.unfocus();
    _scrollToBottom();

    // Add user message to API history
    _apiMessages.add({'role': 'user', 'content': trimmed});

    // Call LLM for Zoe's next response
    _fetchLlmResponse();
  }

  Future<void> _fetchLlmResponse() async {
    if (!mounted || _isCompleting) return;

    setState(() {
      _mascotState = _MascotState.thinking;
      _isLlmThinking = true;
    });

    try {
      final result = await _llm.sendPlacementTurn(
        messages: _apiMessages,
        name: _userName,
        age: int.tryParse(_userAge ?? ''),
      );

      if (!mounted) return;
      if (result == null) return;

      if (result.isComplete) {
        // Keep onboarding as the source of truth. Placement extraction can fill
        // blanks, but it should not replace the name the student already typed.
        if ((_userName == null || _userName!.trim().isEmpty) &&
            result.extractedName != null &&
            result.extractedName!.trim().isNotEmpty) {
          _userName = result.extractedName;
        }
        if ((_userAge == null || _userAge!.trim().isEmpty) &&
            result.extractedAge != null &&
            result.extractedAge!.trim().isNotEmpty) {
          _userAge = result.extractedAge;
        }
        // LLM has assessed the student — navigate to result
        await _goToResult(
          levelCode: result.levelCode ?? 'A2',
          levelName: result.levelName,
          levelDescription:
              result.levelDescription ?? result.evidenceSummary,
          confidence: result.confidence,
          interests: result.interests,
        );
        return;
      }

      final reply = result.reply ?? '';
      if (reply.isEmpty) return;

      // Add Zoe's reply to both histories
      _apiMessages.add({'role': 'model', 'content': reply});
      setState(() {
        _history.add(
          _PlacementBubbleEntry(
            text: reply,
            isElla: true,
            createdAt: DateTime.now(),
          ),
        );
        _mascotState = _MascotState.speaking;
        _isZoeSpeaking = true;
        _isLlmThinking = false;
      });
      _scrollToBottom();

      await _tts.speak(reply).timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      if (!mounted) return;

      setState(() {
        _mascotState = _MascotState.listening;
        _isZoeSpeaking = false;
      });
    } catch (e) {
      if (!mounted) return;
      // On error, show a fallback and keep listening
      const fallback = 'Sorry, could you say that again?';
      _apiMessages.add({'role': 'model', 'content': fallback});
      setState(() {
        _history.add(
          _PlacementBubbleEntry(
            text: fallback,
            isElla: true,
            createdAt: DateTime.now(),
          ),
        );
        _mascotState = _MascotState.listening;
        _isZoeSpeaking = false;
        _isLlmThinking = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _goToResult({
    required String levelCode,
    String? levelName,
    String? levelDescription,
    String? confidence,
    List<String>? interests,
  }) async {
    if (!mounted || _isCompleting) return;
    _isCompleting = true;

    const fallbackLabels = <String, String>{
      'A1': 'First Words',
      'A2': 'Finding My Voice',
      'B1': 'Speaking Freely',
      'B2': 'Almost Fluent',
      'C1': 'Fluent',
    };
    final level = levelCode.toUpperCase();
    final resolvedLevelLabel = levelName ?? fallbackLabels[level] ?? 'Finding My Voice';
    final highlight = levelDescription ??
        'You expressed yourself clearly and stayed engaged throughout the check.';

    if (!mounted) return;
    final provider = context.read<ChatProvider>();
    final profileName = provider.userName?.trim().isNotEmpty == true
        ? provider.userName
        : _userName;
    final profileAge = provider.userAge?.trim().isNotEmpty == true
        ? provider.userAge
        : _userAge;

    // Save profile into ChatProvider for use across the app
    provider.setUserProfile(
      name: profileName,
      age: profileAge,
      location: _userLocation,
      level: level,
      levelLabel: resolvedLevelLabel,
    );

    // Persist to backend (fire-and-forget — don't block navigation on failure)
    final api = ApiService.instance;
    api.ensureAuthenticated().then((_) {
      api.updateProfile(
        name: profileName,
        age: profileAge,
        location: _userLocation,
      );
      api.savePlacement(
        level: level,
        levelLabel: resolvedLevelLabel,
        highlight: highlight,
        transcript: _apiMessages,
        interests: interests,
      );
    }).ignore();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResultScreen(
          level: fallbackLabels.containsKey(level) ? level : 'A2',
          levelName: resolvedLevelLabel,
          name: profileName ?? 'there',
          city: _userLocation,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  Future<void> _toggleMicListening() async {
    if (_isCompleting || _isLlmThinking) return;

    // If Zoe is speaking, stop her and start listening (interruption)
    if (_isZoeSpeaking) {
      await _tts.stop();
      setState(() {
        _isZoeSpeaking = false;
        _mascotState = _MascotState.listening;
      });
    }

    if (_isListening) {
      final text = await _stt.stopListening();
      setState(() {
        _isListening = false;
        _isRecognizing = false;
      });
      if (text.isNotEmpty) {
        _handleUserResponse(text);
      }
      return;
    }

    setState(() {
      _isListening = true;
      _currentTranscript = '';
    });
    _stt.onRecognizingChanged = (isRecognizing) {
      if (mounted) setState(() => _isRecognizing = isRecognizing);
    };
    final started = await _stt.startListening(
      onResult: (text, isFinal) {
        if (mounted) setState(() => _currentTranscript = text);
        if (isFinal && text.isNotEmpty) {
          // Auto-submit when recognizer finishes naturally
          setState(() {
            _isListening = false;
            _isRecognizing = false;
            _currentTranscript = '';
          });
          _handleUserResponse(text);
        }
      },
      silenceMs: 8000,
      possibleSilenceMs: 5000,
    );
    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _isRecognizing = false;
      });
    }
  }

  void _showQuitSheet(BuildContext context) {
    void onExit(BuildContext ctx) {
      Navigator.of(ctx).pop();
      Navigator.of(context).pop();
    }

    if (EllaResponsive.isWide(context)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: _QuitSheetContent(
                showDragHandle: false,
                onExit: () => onExit(ctx),
                onKeepGoing: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: EllaColors.neutralBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: SafeArea(
            top: false,
            child: _QuitSheetContent(
              showDragHandle: true,
              onExit: () => onExit(ctx),
              onKeepGoing: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = EllaResponsive.isWide(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showQuitSheet(context);
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: EllaColors.neutralBg,
      body: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fullHeight = constraints.maxHeight;
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                  // On web, keyboard mode doesn't trigger mascot shrink
                  // (no OS keyboard pops up); only shrink if a real inset appears.
                  final shrinkMascot = isWide
                      ? bottomInset > 0
                      : (bottomInset > 0 || _isKeyboardMode);

                  final contentColumn = Column(
                    children: [
                      // ── Subtitle header ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Text(
                          "Zoe wants to understand what's your current English level",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inconsolata(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: EllaColors.neutralSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // ── Mascot zone ──
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOut,
                        height: shrinkMascot
                            ? fullHeight * 0.25
                            : fullHeight * 0.40,
                        child: Center(
                          child: Hero(
                            tag: _mascotHeroTag,
                            createRectTween: (begin, end) =>
                                MaterialRectArcTween(begin: begin, end: end),
                            child: _PlacementMascot(
                              mascotState: _mascotState,
                              shrink: shrinkMascot,
                            ),
                          ),
                        ),
                      ),

                      // ── Chat list with fade edges ──
                      Expanded(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.06, 0.88, 1.0],
                            ).createShader(bounds);
                          },
                          child: RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Scrollbar(
                                controller: _scrollCtrl,
                                thumbVisibility: false,
                                child: ListView.separated(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 16,
                                  ),
                                  itemCount: _history.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final entry = _history[index];
                                    final hasUserReply = _history.any(
                                      (item) => !item.isElla,
                                    );
                                    return _PlacementCaption(
                                      key: ValueKey(entry.createdAt),
                                      text: entry.text,
                                      isElla: entry.isElla,
                                      isCentered: isWide &&
                                          entry.isElla &&
                                          index == 0 &&
                                          !hasUserReply,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Live transcript preview while listening ──
                      if (_isListening && _currentTranscript.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                          child: _PlacementCaption(
                            text: _currentTranscript,
                            isElla: false,
                            animateIn: false,
                          ),
                        ),

                      // ── Bottom input bar ──
                      _buildInputBar(isWide),
                    ],
                  );

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Stack(
                      children: [
                        // Layer 1: Dashed grid background (full viewport)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _DashedGridPainter()),
                          ),
                        ),

                        // Layer 2: Main content, constrained to 768px on wide
                        isWide
                            ? Center(
                                child: SizedBox(
                                  width: 768,
                                  child: contentColumn,
                                ),
                              )
                            : contentColumn,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      ),   // Scaffold
    );     // PopScope
  }

  Widget _buildInputBar(bool isWide) {
    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 20, 10, isWide ? 24 : 20, 24),
      child: _isKeyboardMode ? _buildKeyboardRow(isWide) : _buildMicRow(isWide),
    );
  }

  Widget _buildMicRow(bool isWide) {
    final bool blocked = _isLlmThinking;

    final keyboardIcon = GestureDetector(
      onTap: blocked
          ? null
          : () {
              setState(() => _isKeyboardMode = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _scrollToBottom();
              });
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted) _textFocusNode.requestFocus();
              });
            },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EllaColors.neutralSurface,
          border: Border.all(
            color: EllaColors.neutralBorder,
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.keyboard_alt_outlined,
          size: 22,
          color: EllaColors.neutralSecondary,
        ),
      ),
    );

    final micButton = GestureDetector(
      onTap: blocked ? null : _toggleMicListening,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_isListening && _isRecognizing)
                const _MicPulseRing(color: EllaColors.mangoMain),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blocked
                      ? EllaColors.neutralBorder
                      : (_isListening && _isRecognizing
                            ? EllaColors.mangoDark
                            : EllaColors.mangoMain),
                  border: Border.all(
                    color: blocked
                        ? EllaColors.neutralSecondary
                        : EllaColors.mangoDark,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: blocked
                          ? EllaColors.neutralSecondary
                          : EllaColors.mangoDark,
                      offset: _isListening && _isRecognizing
                          ? const Offset(0, 1)
                          : const Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: _isListening && _isRecognizing
                    ? const WaveformIcon()
                    : Icon(
                        Icons.mic_rounded,
                        size: 28,
                        color: blocked
                            ? EllaColors.neutralSecondary
                            : EllaColors.neutralPrimary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    final label = Text(
      _isListening
          ? (_isRecognizing ? 'Listening...' : 'Tap to Speak')
          : 'Tap to Speak',
      style: GoogleFonts.baloo2(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _isListening ? EllaColors.mangoDark : EllaColors.neutralMuted,
      ),
    );

    if (isWide) {
      // On wide: mic centered independently; keyboard icon 48px to its left via Stack
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(child: micButton),
                Center(
                  child: Transform.translate(
                    // keyboard icon right edge 48px from mic center:
                    // -(48px gap + 24px half-icon-width) = -72px
                    offset: const Offset(-72, 0),
                    child: keyboardIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile: original Stack layout
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: keyboardIcon,
              ),
              Center(child: micButton),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardRow(bool isWide) {
    final backButton = GestureDetector(
      onTap: () {
        setState(() => _isKeyboardMode = false);
        _textFocusNode.unfocus();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EllaColors.neutralSurface,
          border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: EllaColors.neutralSecondary,
        ),
      ),
    );

    final sendButton = GestureDetector(
      onTap: (_isZoeSpeaking || _isLlmThinking)
          ? null
          : () => _handleUserResponse(_textCtrl.text),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EllaColors.mangoMain,
          border: Border.all(color: EllaColors.mangoDark, width: 2),
          boxShadow: const [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          size: 20,
          color: EllaColors.neutralPrimary,
        ),
      ),
    );

    final textField = TextField(
      controller: _textCtrl,
      focusNode: _textFocusNode,
      textInputAction: TextInputAction.send,
      autofocus: true,
      onSubmitted: _handleUserResponse,
      style: GoogleFonts.baloo2(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: EllaColors.neutralPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Type your reply…',
        hintStyle: GoogleFonts.baloo2(
          fontSize: 15,
          color: EllaColors.neutralMuted,
        ),
        filled: true,
        fillColor: EllaColors.neutralSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: EllaColors.neutralBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: EllaColors.neutralBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: EllaColors.skyMain,
            width: 1.5,
          ),
        ),
      ),
    );

    final row = Row(
      children: [
        backButton,
        const SizedBox(width: 8),
        Expanded(child: textField),
        const SizedBox(width: 8),
        sendButton,
      ],
    );

    return row;
  }
}

// ─── Mascot Widget ────────────────────────────────────────────────────────────

class _PlacementMascot extends StatelessWidget {
  final _MascotState mascotState;
  final bool shrink;

  const _PlacementMascot({required this.mascotState, required this.shrink});

  String get _assetPath => switch (mascotState) {
    _MascotState.speaking => 'assets/mascot-animations/speaking.webp',
    _MascotState.listening => 'assets/mascot-animations/listening.webp',
    _MascotState.thinking =>
      'assets/mascot-animations/regular-thinking.webp',
  };

  @override
  Widget build(BuildContext context) {
    final double size = shrink ? 120.0 : 200.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: size,
      height: size,
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
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Image.asset(
            _assetPath,
            key: ValueKey<_MascotState>(mascotState),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

class _PlacementCaption extends StatelessWidget {
  final String text;
  final bool isElla;
  final bool isCentered;
  final bool animateIn;

  const _PlacementCaption({
    super.key,
    required this.text,
    required this.isElla,
    this.isCentered = false,
    this.animateIn = true,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (EllaResponsive.isWide(context) ? 768.0 : MediaQuery.of(context).size.width) * 0.80,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isElla ? EllaColors.skyLightest : EllaColors.mangoLightest,
            borderRadius: isElla
                ? const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
            border: Border.all(
              color: isElla ? EllaColors.skyLight : EllaColors.mangoLight,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isElla ? EllaColors.skyDark : EllaColors.mangoDark,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isElla ? 'ZOE SAYS' : 'YOU SAID',
                style: GoogleFonts.inconsolata(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isElla ? EllaColors.skyDark : EllaColors.mangoDark,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: isElla
                    ? GoogleFonts.kalam(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: EllaColors.skyDark,
                        height: 1.4,
                      )
                    : GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.neutralPrimary,
                        height: 1.4,
                      ),
              ),
            ],
          ),
        ),
      );

    final alignment = isCentered
        ? Alignment.center
        : (isElla ? Alignment.centerLeft : Alignment.centerRight);

    if (!animateIn) {
      return AnimatedAlign(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: alignment,
        child: bubble,
      );
    }

    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final slideX = isCentered ? 0.0 : (isElla ? -1 : 1) * (1 - value) * 40;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(slideX, 10 * (1 - value)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: alignment,
              child: child,
            ),
          ),
        );
      },
      child: bubble,
    );
  }
}

// ─── Mic Pulse Ring ───────────────────────────────────────────────────────────

class _MicPulseRing extends StatefulWidget {
  final Color color;
  const _MicPulseRing({required this.color});

  @override
  State<_MicPulseRing> createState() => _MicPulseRingState();
}

class _MicPulseRingState extends State<_MicPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _opacity.value),
          ),
        ),
      ),
    );
  }
}

// ─── Background Painter ───────────────────────────────────────────────────────

class _DashedGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EllaColors.neutralBorder.withValues(alpha: 0.50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    const dashLen = 3.0;
    const gapLen = 5.0;

    for (double x = 0; x <= size.width; x += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(x, 0),
        Offset(x, size.height),
        dashLen,
        gapLen,
      );
    }
    for (double y = 0; y <= size.height; y += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(0, y),
        Offset(size.width, y),
        dashLen,
        gapLen,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashLen,
    double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = Offset(dx, dy).distance;
    if (len == 0) return;
    final normX = dx / len;
    final normY = dy / len;
    double dist = 0;
    while (dist < len) {
      final dashEnd = (dist + dashLen).clamp(0.0, len);
      canvas.drawLine(
        Offset(start.dx + normX * dist, start.dy + normY * dist),
        Offset(start.dx + normX * dashEnd, start.dy + normY * dashEnd),
        paint,
      );
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedGridPainter old) => false;
}

// ─── Quit Sheet ───────────────────────────────────────────────────────────────

class _QuitSheetContent extends StatelessWidget {
  final bool showDragHandle;
  final VoidCallback onExit;
  final VoidCallback onKeepGoing;

  const _QuitSheetContent({
    required this.showDragHandle,
    required this.onExit,
    required this.onKeepGoing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EllaColors.neutralBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 4),
        const Text(
          'Exit early?',
          style: TextStyle(
            fontFamily: 'Chillax',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Your progress won't be saved — you'll start the placement check again next time.",
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: onExit,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: EllaColors.error,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: EllaColors.roseDark,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'EXIT',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onKeepGoing,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: EllaColors.neutralBorder,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'KEEP GOING',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: EllaColors.neutralSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
