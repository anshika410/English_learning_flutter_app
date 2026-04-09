import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import 'result_screen.dart';

// ─── Placement conversation turns ─────────────────────────────────────────────

const List<String> _ellaTurns = [
  "Hey! Let's check how good your English is. Tell me — what did you do yesterday?",
  "Great! Do you usually speak English at work or school?",
  "Nice! Can you describe your favourite place to visit and why you love it?",
  "Interesting! What would you do if you had a free day with no plans?",
  "Last one — tell me about someone who inspires you.",
];

// ─── PlacementScreen ──────────────────────────────────────────────────────────

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();

  int _turnCount = 0;
  bool _isEllaTyping = false;
  bool _isKeyboardMode = false;
  bool _isListening = false;

  String? _currentEllaText;
  String? _currentUserText;
  bool _showUserCaption = false;

  // Pulse animation for Ella's avatar when typing
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
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 600), _showNextEllaTurn);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _showNextEllaTurn() {
    if (_turnCount >= _ellaTurns.length) return;
    setState(() {
      _isEllaTyping = true;
      _showUserCaption = false;
      _currentEllaText = null;
    });
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isEllaTyping = false;
        _currentEllaText = _ellaTurns[_turnCount];
      });
      _pulseCtrl.stop();
    });
  }

  void _handleUserResponse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textCtrl.clear();

    setState(() {
      _currentUserText = trimmed;
      _showUserCaption = true;
      _isListening = false;
      _isKeyboardMode = false;
      _turnCount++;
    });

    if (_turnCount >= _ellaTurns.length) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context2, animation, secondary) => const ResultScreen(
              level: 'A2',
              levelName: 'Finding My Voice',
            ),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context2, animation, secondary, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              );
              return FadeTransition(opacity: curved, child: child);
            },
          ),
        );
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), _showNextEllaTurn);
    }
  }

  void _toggleMicListening() {
    if (_isListening) {
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top label ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text(
                'Quick placement check',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.neutralSecondary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Ella avatar (160×160, no circle) ──────────────────────────
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring when Ella is typing
                  if (_isEllaTyping)
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (ctx, child) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: EllaColors.skyMain
                                .withValues(alpha: _pulseOpacity.value),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Image.asset(
                      'images/ella-neutral.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Caption bubble ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildCaption(),
                ),
              ),
            ),

            // ── Input bar ─────────────────────────────────────────────────
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption() {
    if (_isEllaTyping) {
      return _PlacementCaption(
        text: '...',
        isElla: true,
        isTyping: true,
      );
    }
    if (_showUserCaption && _currentUserText != null) {
      return _PlacementCaption(text: _currentUserText!, isElla: false);
    }
    if (_currentEllaText != null) {
      return _PlacementCaption(text: _currentEllaText!, isElla: true);
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputBar() {
    return Container(
      color: EllaColors.neutralBg,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Keyboard icon — pinned to far left
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() => _isKeyboardMode = true),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EllaColors.neutralSurface,
                  border:
                      Border.all(color: EllaColors.neutralBorder, width: 1.5),
                ),
                child: const Icon(
                  Icons.keyboard_alt_outlined,
                  size: 22,
                  color: EllaColors.neutralSecondary,
                ),
              ),
            ),
          ),
          // Mic button — centered
          Center(
            child: GestureDetector(
              onTap: _turnCount < _ellaTurns.length
                  ? _toggleMicListening
                  : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    _MicPulseRing(color: EllaColors.mangoMain),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? EllaColors.mangoDark
                          : EllaColors.mangoMain,
                      border: Border.all(
                          color: EllaColors.mangoDark, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: EllaColors.mangoDark,
                          offset: _isListening
                              ? const Offset(1, 1)
                              : const Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
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
        // Back to mic
        GestureDetector(
          onTap: () => setState(() => _isKeyboardMode = false),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.neutralSurface,
              border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 22,
              color: EllaColors.neutralSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: TextField(
            controller: _textCtrl,
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
        // Send button
        GestureDetector(
          onTap: () => _handleUserResponse(_textCtrl.text),
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
                  offset: Offset(2, 2),
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

// ─── Placement Caption Bubble ─────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(16),
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
            isElla ? 'ELLA SAYS' : 'YOU SAID',
            style: GoogleFonts.inconsolata(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isElla ? EllaColors.skyDark : EllaColors.mangoDark,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (isTyping)
            _TypingDots()
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

// ─── Typing dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BouncingDot(delay: Duration.zero),
        const SizedBox(width: 4),
        _BouncingDot(delay: const Duration(milliseconds: 200)),
        const SizedBox(width: 4),
        _BouncingDot(delay: const Duration(milliseconds: 400)),
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
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      builder: (ctx, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: EllaColors.skyDark,
          ),
        ),
      ),
    );
  }
}

// ─── Mic pulse ring ───────────────────────────────────────────────────────────

class _MicPulseRing extends StatefulWidget {
  final Color color;
  const _MicPulseRing({required this.color});

  @override
  State<_MicPulseRing> createState() => _MicPulseRingState();
}

class _MicPulseRingState extends State<_MicPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
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
      builder: (ctx, child) => Transform.scale(
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
