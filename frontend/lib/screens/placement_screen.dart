import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/continuous_stt_service.dart';
import '../services/llm_service.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
import '../widgets/waveform_icon.dart';
import '../widgets/offline_banner.dart';
import 'result_screen.dart';

// ─── Mascot State ─────────────────────────────────────────────────────────────

enum _MascotState { speaking, listening, thinking }

// ─── Data ─────────────────────────────────────────────────────────────────────

class _PlacementBubbleEntry {
  final String text;
  final bool isElla;

  const _PlacementBubbleEntry({required this.text, required this.isElla});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  static const String _openingLine =
      'Hey, I am Zoe and I love a good conversation. What name should I call you with?';

  final ContinuousSttService _stt = ContinuousSttService();
  final TtsManager _tts = TtsManager();
  final LlmService _llm = LlmService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isKeyboardMode = false;
  bool _isListening = false;
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
    _stt.initialize();
    _tts.initialize();
    Future.delayed(const Duration(milliseconds: 600), _playOpeningLine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheMascotImages) return;
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
        const _PlacementBubbleEntry(text: _openingLine, isElla: true),
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
      _history.add(_PlacementBubbleEntry(text: trimmed, isElla: false));
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
      final result = await _llm.sendPlacementMessage(_apiMessages);

      if (!mounted) return;

      if (result.isComplete) {
        // LLM has assessed the student — extract info and navigate
        _userName = result.name;
        _userAge = result.age;
        _userLocation = result.location;
        await _goToResult(result.assessedLevel ?? 'A2');
        return;
      }

      final reply = result.reply ?? '';
      if (reply.isEmpty) return;

      // Add Zoe's reply to both histories
      _apiMessages.add({'role': 'model', 'content': reply});
      setState(() {
        _history.add(_PlacementBubbleEntry(text: reply, isElla: true));
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
          const _PlacementBubbleEntry(text: fallback, isElla: true),
        );
        _mascotState = _MascotState.listening;
        _isZoeSpeaking = false;
        _isLlmThinking = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _goToResult(String assessedLevel) async {
    if (!mounted || _isCompleting) return;
    _isCompleting = true;

    const labels = <String, String>{
      'A1': 'Starting Out',
      'A2': 'Finding My Voice',
      'B1': 'Speaking with Confidence',
      'B2': 'Expressing with Clarity',
      'C1': 'Near-Native Flow',
    };
    final level = assessedLevel.toUpperCase();
    final levelLabel = labels[level] ?? 'Finding My Voice';
    final highlight =
        'You expressed yourself clearly and stayed engaged throughout the check.';

    if (!mounted) return;
    // Save profile into ChatProvider for use across the app
    context.read<ChatProvider>().setUserProfile(
      name: _userName,
      age: _userAge,
      location: _userLocation,
      level: level,
      levelLabel: levelLabel,
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResultScreen(
          level: labels.containsKey(level) ? level : 'A2',
          levelName: levelLabel,
          highlight: highlight,
          name: _userName ?? 'there',
          city: _userLocation,
          age: _userAge,
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
    if (_isCompleting || _isZoeSpeaking || _isLlmThinking) return;

    if (_isListening) {
      final text = await _stt.stopListening();
      setState(() => _isListening = false);
      if (text.isNotEmpty) {
        _handleUserResponse(text);
      }
      return;
    }

    setState(() {
      _isListening = true;
      _currentTranscript = '';
    });
    final started = await _stt.startListening(
      onResult: (text, isFinal) {
        if (mounted) setState(() => _currentTranscript = text);
      },
    );
    if (!started && mounted) {
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            // Shrink mascot whenever keyboard is visible (reactive to MediaQuery)
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final shrinkMascot = bottomInset > 0 || _isKeyboardMode;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Stack(
                children: [
                  // Layer 1: Dashed grid background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _DashedGridPainter()),
                    ),
                  ),

                  // Layer 2: Main content
                  Column(
                    children: [
                      // ── Subtitle header (replaces "Placement Test") ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Text(
                          "Zoe wants to understand what's your current English level",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inconsolata(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: EllaColors.neutralSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // ── Mascot zone: 40% normally, 25% when keyboard open ──
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: shrinkMascot
                            ? fullHeight * 0.25
                            : fullHeight * 0.40,
                        child: Center(
                          child: _PlacementMascot(
                            mascotState: _mascotState,
                            shrink: shrinkMascot,
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
                                  return _PlacementCaption(
                                    text: entry.text,
                                    isElla: entry.isElla,
                                  );
                                },
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
                          ),
                        ),

                      // ── LLM thinking indicator ──
                      if (_isLlmThinking)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Zoe is thinking…',
                            style: GoogleFonts.inconsolata(
                              fontSize: 12,
                              color: EllaColors.neutralMuted,
                            ),
                          ),
                        ),

                      // ── Bottom input bar ──
                      _buildInputBar(),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),    // SafeArea
          ), // Expanded
        ],
      ),    // Column
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    final bool blocked = _isZoeSpeaking || _isLlmThinking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isListening ? 'Listening… tap to send' : 'Tap to speak',
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _isListening
                ? EllaColors.mangoDark
                : EllaColors.neutralMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: blocked
                  ? null
                  : () {
                      setState(() => _isKeyboardMode = true);
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
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: blocked ? null : _toggleMicListening,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (_isListening)
                        const _MicPulseRing(color: EllaColors.mangoMain),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: blocked
                              ? EllaColors.neutralBorder
                              : (_isListening
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
                              offset: _isListening
                                  ? const Offset(0, 1)
                                  : const Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: _isListening
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
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }

  Widget _buildKeyboardRow() {
    return Row(
      children: [
        GestureDetector(
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
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
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
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
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
        ),
      ],
    );
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

  const _PlacementCaption({required this.text, required this.isElla});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isElla ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
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
      ),
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
