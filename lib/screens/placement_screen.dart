import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/placement_result.dart';
import '../services/stt_service.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
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
      'Hi. You have taken the step to master English speaking. '
      'With this conversation, I will be able to help you get to the next '
      'step of your learning. I am Zoe. What is your name?';

  final SttService _stt = SttService();
  final TtsManager _tts = TtsManager();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  int _userResponses = 0;
  bool _isKeyboardMode = false;
  bool _isListening = false;
  bool _isCompleting = false;
  String _currentTranscript = '';
  _MascotState _mascotState = _MascotState.speaking;
  bool _didPrecacheMascotImages = false;

  final List<_PlacementBubbleEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _stt.initialize();
    _tts.initialize();
    Future.delayed(
      const Duration(milliseconds: 600),
      _requestNextPlacementTurn,
    );
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

  Future<void> _requestNextPlacementTurn() async {
    if (!mounted || _isCompleting) return;

    // Thinking — Zoe is composing her reply
    setState(() => _mascotState = _MascotState.thinking);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isCompleting) return;

    // Add Zoe's message and start speaking
    setState(() {
      _history.add(_PlacementBubbleEntry(text: _openingLine, isElla: true));
      _mascotState = _MascotState.speaking;
    });
    _scrollToBottom();

    // Await TTS — Future resolves when audio finishes
    await _tts.speak(_openingLine);
    if (!mounted) return;

    // Audio done — switch to listening
    setState(() => _mascotState = _MascotState.listening);
  }

  void _handleUserResponse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isCompleting) return;
    _textCtrl.clear();

    setState(() {
      _history.add(_PlacementBubbleEntry(text: trimmed, isElla: false));
      _isListening = false;
      _currentTranscript = '';
      _isKeyboardMode = false;
      _userResponses++;
    });
    _textFocusNode.unfocus();
    _scrollToBottom();

    if (_userResponses >= 3) {
      Future.delayed(const Duration(milliseconds: 300), _goToResult);
      return;
    }

    Future.delayed(
      const Duration(milliseconds: 450),
      _requestNextPlacementTurn,
    );
  }

  Future<void> _goToResult() async {
    if (!mounted || _isCompleting) return;
    _isCompleting = true;

    const placement = PlacementResult(
      cefrLevel: 'A2',
      levelLabel: 'Finding My Voice',
      highlight:
          'You expressed yourself clearly and stayed engaged throughout the check.',
      confidence: 0.6,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResultScreen(
          level: placement.cefrLevel,
          levelName: placement.levelLabel ?? 'Finding My Voice',
          highlight: placement.highlight,
          name: 'Arjun',
          city: 'Kanpur',
          age: '16 years old',
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
    if (_isCompleting || _mascotState == _MascotState.speaking) return;

    if (_isListening) {
      await _stt.stopListening();
      final text = _currentTranscript.trim();
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
      onResult: _onSpeechResult,
      onDone: _onListeningDone,
    );
    if (!started && mounted) {
      setState(() => _isListening = false);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _currentTranscript = result.recognizedWords);
  }

  void _onListeningDone() {
    // OS signalled that recognition stopped (e.g. silence timeout).
    // We do NOT auto-submit — the user must tap stop to send their reply.
    if (!mounted || !_isListening) return;
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fullHeight = constraints.maxHeight;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final shrinkMascot = bottomInset > 0 && _history.length >= 3;

            final circlesCenter = Offset(
              constraints.maxWidth / 2,
              fullHeight / 2,
            );

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Stack(
                children: [
                  // Layer 1: Concentric circles background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ConcentricCirclesPainter(
                          center: circlesCenter,
                        ),
                      ),
                    ),
                  ),

                  // Layer 2: Main content
                  Column(
                    children: [
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

                      // ── Bottom input bar ──
                      _buildInputBar(),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: EllaColors.neutralBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _mascotState == _MascotState.speaking
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
              onTap: _toggleMicListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    const _MicPulseRing(color: EllaColors.mangoMain),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? EllaColors.mangoDark
                          : EllaColors.mangoMain,
                      border: Border.all(
                        color: EllaColors.mangoDark,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: EllaColors.mangoDark,
                          offset: _isListening
                              ? const Offset(0, 1)
                              : const Offset(0, 5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 28,
                      color: _isListening
                          ? Colors.white
                          : EllaColors.neutralPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          onTap: _mascotState == _MascotState.speaking
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
    _MascotState.thinking => 'assets/mascot-animations/regular-thinking.webp',
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
                        fontWeight: FontWeight.w700,
                        color: EllaColors.skyDark,
                        height: 1.4,
                      )
                    : GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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

class _ConcentricCirclesPainter extends CustomPainter {
  final Offset center;

  const _ConcentricCirclesPainter({required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EllaColors.neutralBorder.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 6 concentric circles, innermost radius ~80px, spaced 60px apart
    for (int i = 1; i <= 6; i++) {
      canvas.drawCircle(center, 80.0 + (i - 1) * 60.0, paint);
    }
  }

  @override
  bool shouldRepaint(_ConcentricCirclesPainter old) => old.center != center;
}
