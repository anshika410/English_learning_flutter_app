import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/chat_message.dart';
import '../models/placement_result.dart';
import '../services/llm_service.dart';
import '../services/stt_service.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
import 'result_screen.dart';

class _PlacementBubbleEntry {
  final String text;
  final bool isElla;

  const _PlacementBubbleEntry({required this.text, required this.isElla});
}

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen>
    with TickerProviderStateMixin {
  static const int _minTurns = 5;
  static const int _maxTurns = 8;

  final LlmService _llm = LlmService();
  final SttService _stt = SttService();
  final TtsManager _tts = TtsManager();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  int _userResponses = 0;
  bool _isEllaTyping = false;
  bool _isKeyboardMode = false;
  bool _isListening = false;
  bool _isCompleting = false;
  String _currentTranscript = '';

  final List<_PlacementBubbleEntry> _history = [];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.45,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _stt.initialize();
    _tts.initialize();
    Future.delayed(
      const Duration(milliseconds: 600),
      _requestNextPlacementTurn,
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stt.dispose();
    _tts.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  List<ChatMessage> _chatHistory() {
    return _history
        .map(
          (entry) => ChatMessage(
            role: entry.isElla ? MessageRole.assistant : MessageRole.user,
            content: entry.text,
          ),
        )
        .toList();
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
    if (_userResponses >= _maxTurns) {
      await _goToResult();
      return;
    }

    setState(() => _isEllaTyping = true);
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();

    PlacementTurnDecision decision;
    try {
      decision = await _llm.nextPlacementTurn(
        history: _chatHistory(),
        userResponses: _userResponses,
        minTurns: _minTurns,
        maxTurns: _maxTurns,
      );
    } catch (_) {
      decision = PlacementTurnDecision(
        continuePlacement: _userResponses < _minTurns,
        nextQuestion: _userResponses < _minTurns
            ? 'Can you tell me about a recent experience in English?'
            : '',
        reason: 'fallback',
      );
    }

    if (!mounted || _isCompleting) return;

    if (!decision.continuePlacement && _userResponses >= _minTurns) {
      setState(() => _isEllaTyping = false);
      _pulseCtrl.stop();
      await _goToResult();
      return;
    }

    final question = decision.nextQuestion.trim().isNotEmpty
        ? decision.nextQuestion.trim()
        : 'Can you describe your day and what you enjoyed most?';

    setState(() {
      _isEllaTyping = false;
      _history.add(_PlacementBubbleEntry(text: question, isElla: true));
    });
    _pulseCtrl.stop();
    _scrollToBottom();
    _tts.speak(question);
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

    Future.delayed(
      const Duration(milliseconds: 450),
      _requestNextPlacementTurn,
    );
  }

  Future<void> _goToResult() async {
    if (!mounted || _isCompleting) return;
    _isCompleting = true;

    PlacementResult placement = const PlacementResult(
      cefrLevel: 'A2',
      levelLabel: 'Finding My Voice',
      highlight:
          'You expressed yourself clearly and stayed engaged throughout the check.',
      confidence: 0.6,
    );

    try {
      if (_llm.activeConfig.isConfigured) {
        placement = await _llm.evaluatePlacement(_chatHistory());
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ResultScreen(
          level: placement.cefrLevel,
          levelName: placement.levelLabel ?? 'Finding My Voice',
          highlight: placement.highlight,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
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
    if (_isCompleting || _isEllaTyping) return;

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
    if (!mounted || !_isListening) return;
    final text = _currentTranscript.trim();
    setState(() => _isListening = false);
    if (text.isNotEmpty) {
      _handleUserResponse(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardUp = bottomInset > 0;
    final avatarSize = keyboardUp && _history.length >= 3 ? 120.0 : 160.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 4),
                child: Text(
                  'Quick placement check',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EllaColors.neutralPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isEllaTyping)
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: EllaColors.skyMain.withValues(
                                alpha: _pulseOpacity.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: avatarSize,
                      height: avatarSize,
                      child: Image.asset(
                        'images/ella-neutral.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _history.length + (_isEllaTyping ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (_isEllaTyping && index == _history.length) {
                        return const _PlacementCaption(
                          text: '...',
                          isElla: true,
                          isTyping: true,
                        );
                      }
                      final entry = _history[index];
                      return _PlacementCaption(
                        text: entry.text,
                        isElla: entry.isElla,
                      );
                    },
                  ),
                ),
              ),
              if (_isListening && _currentTranscript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: _PlacementCaption(
                    text: _currentTranscript,
                    isElla: false,
                  ),
                ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: EllaColors.neutralBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
              onTap: _isEllaTyping
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
                      color: Colors.white,
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
          onTap: _isEllaTyping
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
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacementCaption extends StatelessWidget {
  final String text;
  final bool isElla;
  final bool isTyping;

  const _PlacementCaption({
    required this.text,
    required this.isElla,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          if (isTyping)
            const _TypingDots()
          else
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
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _BouncingDot(delay: Duration.zero),
        SizedBox(width: 4),
        _BouncingDot(delay: Duration(milliseconds: 200)),
        SizedBox(width: 4),
        _BouncingDot(delay: Duration(milliseconds: 400)),
      ],
    );
  }
}

class _BouncingDot extends StatefulWidget {
  final Duration delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: EllaColors.skyDark,
          ),
        ),
      ),
    );
  }
}

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
