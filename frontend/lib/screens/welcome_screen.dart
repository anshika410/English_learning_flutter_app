import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'placement_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TtsManager _tts = TtsManager();
  bool _isSpeakingIntro = false;
  bool _didPrecacheMascotImages = false;
  bool _showStartButton = false;
  String _visibleHeading = '';
  String _visibleSubline = '';

  static const String _introHeading = 'Hi, I am Zoe!';
  static const String _introSubline =
      'Your English speaking buddy. Let\'s practice one easy step at a time';
  String get _introSpeech => '$_introHeading $_introSubline';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playIntroSpeech());
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
    _didPrecacheMascotImages = true;
  }

  Future<void> _playIntroSpeech() async {
    if (!mounted) return;

    // On web, browser blocks TTS without a user gesture — skip auto-speak
    // and show the UI immediately instead.
    if (kIsWeb) {
      setState(() {
        _visibleHeading = _introHeading;
        _visibleSubline = _introSubline;
        _isSpeakingIntro = false;
        _showStartButton = true;
      });
      return;
    }

    setState(() {
      _isSpeakingIntro = true;
      _showStartButton = false;
      _visibleHeading = '';
      _visibleSubline = '';
    });

    try {
      await _tts.initialize();
      final Future<void> speechFuture = _tts.speak(_introSpeech);
      await _typeIntroText();
      // Wait for TTS but cap at 8s — web TTS can hang indefinitely
      await speechFuture.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {
      // Keep UI resilient even if a TTS engine fails.
    } finally {
      if (mounted) {
        setState(() {
          _isSpeakingIntro = false;
          _showStartButton = true;
        });
      }
    }
  }

  Future<void> _typeIntroText() async {
    final int baseDelayMs = _baseTypeDelayMs();
    await _typeTextWithSpeechPacing(
      fullText: _introHeading,
      update: (value) => _visibleHeading = value,
      baseDelayMs: baseDelayMs,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await _typeTextWithSpeechPacing(
      fullText: _introSubline,
      update: (value) => _visibleSubline = value,
      baseDelayMs: baseDelayMs,
    );
  }

  Future<void> _typeTextWithSpeechPacing({
    required String fullText,
    required void Function(String value) update,
    required int baseDelayMs,
  }) async {
    for (int i = 1; i <= fullText.length; i++) {
      if (!mounted) return;
      final String current = fullText.substring(0, i);
      final String typedChar = fullText.substring(i - 1, i);
      setState(() => update(current));
      await Future<void>.delayed(
        Duration(milliseconds: baseDelayMs + _punctuationPauseMs(typedChar)),
      );
    }
  }

  int _baseTypeDelayMs() {
    // Slower pacing so typewriter matches TTS speech speed (~4-5s for full text).
    return 52;
  }

  int _punctuationPauseMs(String char) {
    switch (char) {
      case ',':
        return 70;
      case '.':
      case '!':
      case '?':
        return 120;
      case '\'':
        return 8;
      case ' ':
        return 6;
      default:
        return 0;
    }
  }

  void _navigateToPlacement() {
    _tts.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context2, animation, secondary) =>
            const PlacementScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context2, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: Stack(
        children: [
          // Animated confetti dots across the full background
          const IgnorePointer(child: _ConfettiBackground()),

          // Decorative corner blocks (behind everything, non-interactive)
          const IgnorePointer(child: _CornerBlocks()),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Zoe mascot — animated webp looping inside circle
                  _ZoeMascot(isSpeaking: _isSpeakingIntro),

                  const SizedBox(height: 20),

                  // Heading — extra bold
                  Text(
                    _visibleHeading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Chillax',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: EllaColors.neutralPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warm support line
                  Text(
                    _visibleSubline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralSecondary,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  AnimatedSlide(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    offset: _showStartButton
                        ? Offset.zero
                        : const Offset(0, 0.18),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 320),
                      opacity: _showStartButton ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_showStartButton,
                        child: EllaPrimaryButton(
                          label: 'Start learning',
                          onTap: _navigateToPlacement,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zoe Mascot ──────────────────────────────────────────────────────────────

class _ZoeMascot extends StatelessWidget {
  final bool isSpeaking;

  const _ZoeMascot({required this.isSpeaking});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
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
            isSpeaking
                ? 'assets/mascot-animations/speaking.webp'
                : 'assets/mascot-animations/listening.webp',
            key: ValueKey<bool>(isSpeaking),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// ─── Corner Blocks ───────────────────────────────────────────────────────────

class _CornerBlocks extends StatelessWidget {
  const _CornerBlocks();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left — Mango (orange) — tallest, most dominant
        _CornerBlock(
          color: EllaColors.mangoMain,
          alignment: Alignment.topLeft,
          xOffset: -88,
          yOffset: -96,
          rotationDeg: -20,
          width: 170,
          height: 360,
        ),
        // Top-right — Sky (blue)
        _CornerBlock(
          color: EllaColors.skyMain,
          alignment: Alignment.topRight,
          xOffset: 88,
          yOffset: -96,
          rotationDeg: 20,
          width: 170,
          height: 350,
        ),
        // Bottom-left — Sunny Yellow
        _CornerBlock(
          color: EllaColors.sunnyYellow,
          alignment: Alignment.bottomLeft,
          xOffset: -88,
          yOffset: 92,
          rotationDeg: 20,
          width: 180,
          height: 340,
        ),
        // Bottom-right — Rose (pink)
        _CornerBlock(
          color: EllaColors.roseMain,
          alignment: Alignment.bottomRight,
          xOffset: 88,
          yOffset: 92,
          rotationDeg: -20,
          width: 180,
          height: 340,
        ),
      ],
    );
  }
}

class _CornerBlock extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final double xOffset;
  final double yOffset;
  final double rotationDeg;
  final double width;
  final double height;

  const _CornerBlock({
    required this.color,
    required this.alignment,
    required this.xOffset,
    required this.yOffset,
    required this.rotationDeg,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(xOffset, yOffset),
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(painter: _BlockPainter(color: color)),
          ),
        ),
      ),
    );
  }
}

// ─── Block painter (solid fill + subtle monochrome dots) ─────────────────────

class _BlockPainter extends CustomPainter {
  final Color color;

  _BlockPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

    final dotColor = Color.lerp(color, Colors.black, 0.22)!;
    final dotPaint = Paint()..color = dotColor.withValues(alpha: 0.18);
    const spacing = 14.0;
    const radius = 1.4;

    for (double y = spacing * 0.7; y < size.height; y += spacing) {
      for (double x = spacing * 0.7; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => oldDelegate.color != color;
}

// ─── Confetti Background ─────────────────────────────────────────────────────

// Each entry: (normalised x, normalised y, color index, radius)
const List<_DotData> _kDots = [
  _DotData(0.08, 0.07, 0, 4.0),
  _DotData(0.28, 0.10, 2, 3.8),
  _DotData(0.54, 0.09, 1, 3.2),
  _DotData(0.82, 0.12, 3, 4.4),
  _DotData(0.16, 0.25, 3, 4.0),
  _DotData(0.44, 0.21, 0, 3.4),
  _DotData(0.72, 0.24, 1, 4.0),
  _DotData(0.90, 0.30, 2, 3.4),
  _DotData(0.09, 0.40, 0, 4.2),
  _DotData(0.33, 0.37, 2, 3.4),
  _DotData(0.58, 0.42, 1, 4.0),
  _DotData(0.86, 0.47, 3, 3.6),
  _DotData(0.18, 0.56, 0, 3.6),
  _DotData(0.48, 0.60, 1, 4.0),
  _DotData(0.75, 0.55, 2, 4.4),
  _DotData(0.92, 0.64, 3, 3.2),
  _DotData(0.07, 0.71, 0, 4.0),
  _DotData(0.31, 0.74, 1, 3.2),
  _DotData(0.60, 0.78, 2, 3.8),
  _DotData(0.84, 0.83, 0, 4.0),
  _DotData(0.14, 0.88, 3, 3.4),
  _DotData(0.45, 0.92, 2, 3.8),
  _DotData(0.71, 0.89, 1, 3.6),
  _DotData(0.90, 0.93, 0, 3.2),
];

class _DotData {
  final double x;
  final double y;
  final int colorIdx;
  final double radius;

  const _DotData(this.x, this.y, this.colorIdx, this.radius);
}

const List<Color> _kDotColors = [
  EllaColors.mangoMain,
  EllaColors.skyMain,
  EllaColors.limeMain,
  EllaColors.roseMain,
];

class _ConfettiBackground extends StatefulWidget {
  const _ConfettiBackground();

  @override
  State<_ConfettiBackground> createState() => _ConfettiBackgroundState();
}

class _ConfettiBackgroundState extends State<_ConfettiBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(animValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double animValue;

  _ConfettiPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _kDots.length; i++) {
      final dot = _kDots[i];
      final color = _kDotColors[dot.colorIdx];
      final paint = Paint()..color = color.withValues(alpha: 0.38);

      // Each dot gets a unique phase so they don't all move in sync
      final phase = (i / _kDots.length) * math.pi * 2;
      final driftY = math.sin(animValue * math.pi * 2 + phase) * 5.0;

      final cx = dot.x * size.width;
      final cy = dot.y * size.height + driftY;

      canvas.drawCircle(Offset(cx, cy), dot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}
