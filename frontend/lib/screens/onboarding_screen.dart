import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../theme/ella_theme.dart';
import '../theme/ella_responsive.dart';
import '../utils/name_formatting.dart';
import '../widgets/ella_primary_button.dart';
import 'placement_screen.dart';

enum _OnboardingStep { name, age }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// Idle mascot cycle for onboarding: listening(4s) → juggling(4s) → listening(4s) → bubblepop(4s) → repeat
const List<String> _kOnboardingIdleAssets = [
  'assets/mascot-animations/listening.webp',
  'assets/mascot-animations/juggling.webp',
  'assets/mascot-animations/listening.webp',
  'assets/mascot-animations/bubblepop.webp',
];
const Duration _kOnboardingIdleHold = Duration(seconds: 4);

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const String _mascotHeroTag = 'zoe-onboarding-placement-mascot';

  _OnboardingStep _step = _OnboardingStep.name;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _ageFocus = FocusNode();

  bool _nameValid = false;
  bool _ageValid = false;
  bool _didPrecacheMascotImages = false;
  String? _fieldError;

  // Idle animation loop state
  String _mascotAsset = _kOnboardingIdleAssets[0];
  int _idleStep = 0;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      setState(() {
        _nameValid = _nameCtrl.text.trim().length >= 2;
        if (_nameValid) _fieldError = null;
      });
    });
    _ageCtrl.addListener(() {
      final v = int.tryParse(_ageCtrl.text.trim());
      setState(() {
        _ageValid = v != null && v > 0 && v < 120;
        if (_ageValid) _fieldError = null;
      });
    });
    // Start idle mascot loop after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIdleLoop());
    // Auto-focus name field after brief delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheMascotImages) return;
    for (final asset in _kOnboardingIdleAssets) {
      precacheImage(AssetImage(asset), context);
    }
    _didPrecacheMascotImages = true;
  }

  void _startIdleLoop() {
    _idleTimer?.cancel();
    _idleStep = 0;
    if (mounted) setState(() => _mascotAsset = _kOnboardingIdleAssets[0]);
    _scheduleNextIdleStep();
  }

  void _scheduleNextIdleStep() {
    _idleTimer = Timer(_kOnboardingIdleHold, () {
      if (!mounted) return;
      _idleStep = (_idleStep + 1) % _kOnboardingIdleAssets.length;
      setState(() => _mascotAsset = _kOnboardingIdleAssets[_idleStep]);
      _scheduleNextIdleStep();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    super.dispose();
  }

  void _onNameNext() {
    if (!_nameValid) {
      setState(() => _fieldError = 'Please enter your name');
      return;
    }
    final normalizedName = normalizeDisplayName(_nameCtrl.text);
    setState(() => _fieldError = null);
    _nameCtrl.value = _nameCtrl.value.copyWith(
      text: normalizedName,
      selection: TextSelection.collapsed(offset: normalizedName.length),
      composing: TextRange.empty,
    );
    _nameFocus.unfocus();
    setState(() => _step = _OnboardingStep.age);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ageFocus.requestFocus();
    });
  }

  void _onAgeNext() {
    if (!_ageValid) {
      setState(() => _fieldError = 'Please enter a valid age');
      return;
    }
    setState(() => _fieldError = null);
    _ageFocus.unfocus();
    context.read<ChatProvider>().setUserProfile(
      name: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
    );
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => const PlacementScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNameStep = _step == _OnboardingStep.name;
    final onNext = isNameStep ? _onNameNext : _onAgeNext;

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: Stack(
        children: [
          const IgnorePointer(child: _ConfettiBackground()),
          const IgnorePointer(child: _CornerBlocks()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Zoe mascot — always idle-loops on this screen
                  Hero(
                    tag: _mascotHeroTag,
                    createRectTween: (begin, end) =>
                        MaterialRectArcTween(begin: begin, end: end),
                    child: _ZoeMascot(assetPath: _mascotAsset),
                  ),

                  const SizedBox(height: 24),

                  // Zoe's question (animated switcher for step transition)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Text(
                      isNameStep
                          ? 'What should I call you?'
                          : 'Welcome ${normalizeDisplayName(_nameCtrl.text)}. How old are you?',
                      key: ValueKey(_step),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Chillax',
                        fontSize: EllaResponsive.questionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: EllaColors.neutralPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Text input — capped width on wide screens
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: EllaResponsive.isWide(context)
                            ? EllaResponsive.textFieldMaxWidthWide
                            : double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                            child: isNameStep
                                ? _buildTextField(
                                    key: const ValueKey('name'),
                                    controller: _nameCtrl,
                                    focusNode: _nameFocus,
                                    hint: 'Your name',
                                    inputAction: TextInputAction.next,
                                    capitalization: TextCapitalization.words,
                                    onSubmitted: (_) => _onNameNext(),
                                  )
                                : _buildTextField(
                                    key: const ValueKey('age'),
                                    controller: _ageCtrl,
                                    focusNode: _ageFocus,
                                    hint: 'Your age',
                                    inputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
                                    onSubmitted: (_) => _onAgeNext(),
                                  ),
                          ),
                          // Inline validation error
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                            child: _fieldError != null
                                ? Padding(
                                    key: ValueKey(_fieldError),
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      left: 4,
                                    ),
                                    child: Text(
                                      _fieldError!,
                                      style: GoogleFonts.baloo2(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: EllaColors.error,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no-error')),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Proceed button — always enabled; validation shows inline error
                  Center(
                    child: EllaPrimaryButton(
                      label: 'Proceed',
                      onTap: onNext,
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

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputAction inputAction,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
  }) {
    final radius = EllaResponsive.textFieldBorderRadius(context);
    final isWide = EllaResponsive.isWide(context);
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      textInputAction: inputAction,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      style: GoogleFonts.baloo2(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: EllaColors.neutralPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.baloo2(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: EllaColors.neutralMuted,
        ),
        filled: true,
        fillColor: EllaColors.neutralSurface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isWide
              ? EllaResponsive.textFieldContentPaddingHorizontalWide
              : 20,
          vertical: isWide
              ? EllaResponsive.textFieldContentPaddingVerticalWide
              : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(
            color: EllaColors.neutralBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(
            color: EllaColors.neutralBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: EllaColors.skyMain, width: 2),
        ),
      ),
    );
  }
}

// ─── Zoe Mascot ──────────────────────────────────────────────────────────────

class _ZoeMascot extends StatelessWidget {
  final String assetPath;

  const _ZoeMascot({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    final size = EllaResponsive.mascotSize(context);
    return Container(
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
            assetPath,
            key: ValueKey<String>(assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
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
    final wide = EllaResponsive.isWide(context);
    final xOff = wide
        ? EllaResponsive.blockXOffsetWide
        : EllaResponsive.blockXOffsetMobile;
    final yOffTop = wide
        ? EllaResponsive.blockYOffsetTopWide
        : EllaResponsive.blockYOffsetTopMobile;
    final yOffBot = wide
        ? EllaResponsive.blockYOffsetBottomWide
        : EllaResponsive.blockYOffsetBottomMobile;
    final wNarrow = wide
        ? EllaResponsive.blockWidthNarrowWide
        : EllaResponsive.blockWidthNarrowMobile;
    final wWide = wide
        ? EllaResponsive.blockWidthWideWide
        : EllaResponsive.blockWidthWideMobile;
    final hTall = wide
        ? EllaResponsive.blockHeightTallWide
        : EllaResponsive.blockHeightTallMobile;
    final hMid = wide
        ? EllaResponsive.blockHeightMidWide
        : EllaResponsive.blockHeightMidMobile;
    final hShort = wide
        ? EllaResponsive.blockHeightShortWide
        : EllaResponsive.blockHeightShortMobile;

    return Stack(
      children: [
        _CornerBlock(
          color: EllaColors.mangoMain,
          alignment: Alignment.topLeft,
          xOffset: -xOff,
          yOffset: -yOffTop,
          rotationDeg: -20,
          width: wNarrow,
          height: hTall,
        ),
        _CornerBlock(
          color: EllaColors.skyMain,
          alignment: Alignment.topRight,
          xOffset: xOff,
          yOffset: -yOffTop,
          rotationDeg: 20,
          width: wNarrow,
          height: hMid,
        ),
        _CornerBlock(
          color: EllaColors.sunnyYellow,
          alignment: Alignment.bottomLeft,
          xOffset: -xOff,
          yOffset: yOffBot,
          rotationDeg: 20,
          width: wWide,
          height: hShort,
        ),
        _CornerBlock(
          color: EllaColors.roseMain,
          alignment: Alignment.bottomRight,
          xOffset: xOff,
          yOffset: yOffBot,
          rotationDeg: -20,
          width: wWide,
          height: hShort,
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
