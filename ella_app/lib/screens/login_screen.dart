// Login — Figma "Onboarding / Login / Email login / Magic Link" frames.
// Figma provides visual proportions and assets; layout is responsive so the
// screens hold up across short, tall, narrow, and high-density phones.
// Auth logic (Google Sign-In events, web One Tap, magic link) is unchanged.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import '../core/text_styles.dart';
import '../core/theme_colors.dart';
import '../services/audio_service.dart';
import '../services/ella_api_service.dart';
import 'child_view/widgets/ella_primary_button.dart';
import 'child_view/widgets/onboarding_scenery.dart';
import 'child_view/widgets/zoe_mascot.dart';
import 'google_sign_in_button.dart';

const String _kGoogleLoginAsset = 'assets/auth/google-login.svg';
const String _kEnvelopeOpenAsset = 'assets/auth/envelope-open.svg';
const String _kPaperPlaneRightAsset = 'assets/auth/paper-plane-right.svg';

class LoginScreen extends StatefulWidget {
  final EllaApiService? api;

  /// Kept true in production. Tests can disable plugin-backed Google listeners
  /// while still exercising email and magic-link UI states.
  final bool enableGoogleAuth;

  const LoginScreen({super.key, this.api, this.enableGoogleAuth = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final EllaApiService _api;

  bool _isLoading = false;
  bool _showEmailInput = false;
  bool _magicLinkSent = false;

  // Intro animation: the mascot slides up into place first, then the title +
  // login options fade/slide in behind it. Runs once on the initial login stage.
  late final AnimationController _introController;
  late final Animation<double> _mascotFade;
  late final Animation<Offset> _mascotSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  bool _introStarted = false;

  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _focusScrollTimer;

  StreamSubscription<gsi.GoogleSignInAuthenticationEvent>?
  _googleSignInSubscription;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? EllaApiService();
    _emailFocusNode.addListener(_onFocusChange);

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _mascotFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _mascotSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );
    _contentFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    if (!widget.enableGoogleAuth) return;

    // Listen to Google Sign-In account changes (crucial for Web iframe button clicks)
    _googleSignInSubscription = gsi.GoogleSignIn.instance.authenticationEvents
        .listen((gsi.GoogleSignInAuthenticationEvent event) async {
          if (event is gsi.GoogleSignInAuthenticationEventSignIn) {
            final account = event.user;
            try {
              final gsi.GoogleSignInAuthentication googleAuth =
                  account.authentication;
              final String? idToken = googleAuth.idToken;
              if (idToken != null) {
                final success = await _api.loginWithGoogle(idToken);
                if (success && mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                } else {
                  _showError('Google Login failed on backend.');
                }
              } else {
                _showError('Google Login failed: no idToken.');
              }
            } catch (e) {
              _showError('Google Login Error: $e');
            }
          }
        });

    // Automatically prompt Google One Tap / FedCM when visiting the site (Web only)
    if (kIsWeb) {
      Future.microtask(() async {
        try {
          final lightweightAuth = gsi.GoogleSignIn.instance
              .attemptLightweightAuthentication();
          if (lightweightAuth != null) {
            final googleUser = await lightweightAuth;
            if (googleUser != null) {
              final auth = googleUser.authentication;
              final idToken = auth.idToken;
              if (idToken != null) {
                final success = await _api.loginWithGoogle(idToken);
                if (success && mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                } else {
                  _showError('One Tap Login failed on backend.');
                }
              } else {
                _showError('One Tap failed: no idToken.');
              }
            } else {
              _showError('One Tap failed: googleUser is null.');
            }
          }
        } catch (e) {
          _showError('One Tap Error: $e');
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start the intro once we can read reduced-motion. If animations are
    // disabled, jump straight to the settled state.
    if (!_introStarted) {
      _introStarted = true;
      if (MediaQuery.of(context).disableAnimations) {
        _introController.value = 1.0;
      } else {
        _introController.forward();
      }
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _googleSignInSubscription?.cancel();
    _focusScrollTimer?.cancel();
    _emailFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus) {
      _focusScrollTimer?.cancel();
      _focusScrollTimer = Timer(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final gsi.GoogleSignInAccount googleUser;

      try {
        googleUser = await gsi.GoogleSignIn.instance.authenticate();
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('cancel')) {
          // User cancelled the standard account picker. Quietly return.
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        rethrow;
      }

      final gsi.GoogleSignInAuthentication googleAuth =
          googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken != null) {
        final success = await _api.loginWithGoogle(idToken);
        if (success && mounted) {
          // Restart app to pick up auth state
          Navigator.of(context).pushReplacementNamed('/');
        } else {
          _showError('Google login failed on backend.');
        }
      }
    } catch (e) {
      _showError('Google Sign In Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await _api.requestMagicLink(email);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _magicLinkSent = success;
    });
    if (!success) {
      _showError('Failed to send magic link. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _resetToButtons() {
    setState(() {
      _magicLinkSent = false;
      _showEmailInput = false;
      _emailController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !(_showEmailInput || _magicLinkSent),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _resetToButtons();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FAFA),
        body: OnboardingScenery(
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = _AuthLayoutMetrics.from(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );

                    if (!_showEmailInput && !_magicLinkSent) {
                      return _buildLoginStage(context, metrics);
                    }
                    return _buildCenteredStage(
                      context: context,
                      metrics: metrics,
                      child: _showEmailInput && !_magicLinkSent
                          ? _buildEmailForm(metrics)
                          : _buildMagicLinkSent(metrics),
                    );
                  },
                ),
              ),

              // Back button for the email input / success states.
              if (_showEmailInput || _magicLinkSent)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      _AuthLayoutMetrics.backButtonInsetFor(
                        MediaQuery.sizeOf(context).height,
                      ),
                  left: _AuthLayoutMetrics.horizontalPaddingFor(
                    MediaQuery.sizeOf(context).width,
                  ),
                  child: _BackCircleButton(onTap: _resetToButtons),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginStage(BuildContext context, _AuthLayoutMetrics metrics) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.safeHeight),
        child: Column(
          children: [
            SizedBox(height: metrics.topMascotInset),
            FadeTransition(
              opacity: _mascotFade,
              child: SlideTransition(
                position: _mascotSlide,
                child: _buildMascot(metrics),
              ),
            ),
            SizedBox(height: metrics.loginTitleGap),
            FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: metrics.contentWidth),
                  child: Column(
                    children: [
                      Text(
                        'ZoSpeak',
                        textAlign: TextAlign.center,
                        style: EllaTextStyles.authDisplay,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Talk More. Grow Your English',
                        textAlign: TextAlign.center,
                        style: EllaTextStyles.authTitle,
                      ),
                      SizedBox(height: metrics.loginActionsGap),
                      _buildLoginButtons(metrics),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: metrics.backdropReserve),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredStage({
    required BuildContext context,
    required _AuthLayoutMetrics metrics,
    required Widget child,
  }) {
    final groupHeight = _magicLinkSent ? 164.0 : 296.0;
    final minStageHeight =
        2 *
        (metrics.topMascotInset +
            metrics.mascotSize +
            metrics.centeredGroupGap +
            groupHeight / 2);
    final stageHeight = math.max(metrics.safeHeight, minStageHeight);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
      child: SizedBox(
        height: stageHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: metrics.topMascotInset,
              child: _buildMascot(metrics),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.contentWidth),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMascot(_AuthLayoutMetrics metrics) {
    return ZoeMascot(
      mode: ZoeMascotMode.listening,
      size: metrics.mascotSize,
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );
  }

  Widget _buildLoginButtons(_AuthLayoutMetrics metrics) {
    final indicatorSize = _clampDouble(metrics.buttonHeight * 0.32, 20, 24);

    return Column(
      children: [
        // Google Login — on web the platform-rendered GIS button must be used
        // (auth happens inside its iframe); native gets the Figma-styled button.
        if (kIsWeb)
          SizedBox(
            width: double.infinity,
            height: metrics.buttonHeight,
            child: getGoogleSignInButton(),
          )
        else
          EllaPrimaryButton(
            label: 'Continue With Google',
            height: metrics.buttonHeight,
            horizontalPadding: 16,
            leadingGap: 12,
            leading: _isLoading
                ? SizedBox(
                    width: indicatorSize,
                    height: indicatorSize,
                    child: const CircularProgressIndicator(
                      color: EllaColors.onPrimary,
                      strokeWidth: 3,
                    ),
                  )
                : SvgPicture.asset(
                    _kGoogleLoginAsset,
                    width: metrics.googleIconSize,
                    height: metrics.googleIconSize,
                  ),
            onTap: _isLoading ? null : _handleGoogleSignIn,
          ),
        SizedBox(height: metrics.buttonGap),

        EllaPrimaryButton(
          label: 'Continue With Email',
          height: metrics.buttonHeight,
          horizontalPadding: 16,
          leadingGap: 12,
          variant: EllaButtonVariant.outline,
          leading: SvgPicture.asset(
            _kEnvelopeOpenAsset,
            width: metrics.authIconSize,
            height: metrics.authIconSize,
          ),
          onTap: _isLoading
              ? null
              : () => setState(() => _showEmailInput = true),
        ),
      ],
    );
  }

  Widget _buildEmailForm(_AuthLayoutMetrics metrics) {
    final indicatorSize = _clampDouble(metrics.buttonHeight * 0.32, 20, 24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign In With Email',
          textAlign: TextAlign.center,
          style: EllaTextStyles.authTitle,
        ),
        SizedBox(height: metrics.emailTitleGap),
        Text(
          'We will send you a link. No password needed',
          textAlign: TextAlign.center,
          style: EllaTextStyles.authBody,
        ),
        SizedBox(height: metrics.formGap),
        SizedBox(
          height: metrics.buttonHeight,
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textAlignVertical: TextAlignVertical.center,
            style: EllaTextStyles.authBody,
            decoration: InputDecoration(
              hintText: 'Eg. xyz@gmail.com',
              hintStyle: EllaTextStyles.authBody.copyWith(
                color: EllaColors.textTertiary,
              ),
              filled: true,
              fillColor: EllaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: EllaColors.border,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: EllaColors.border,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: EllaColors.berryDark,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: metrics.formGap),
        EllaPrimaryButton(
          label: 'Send Me a Link',
          height: metrics.buttonHeight,
          horizontalPadding: 16,
          leadingGap: 12,
          leading: _isLoading
              ? SizedBox(
                  width: indicatorSize,
                  height: indicatorSize,
                  child: const CircularProgressIndicator(
                    color: EllaColors.onPrimary,
                    strokeWidth: 3,
                  ),
                )
              : SvgPicture.asset(
                  _kPaperPlaneRightAsset,
                  width: metrics.authIconSize,
                  height: metrics.authIconSize,
                ),
          onTap: _isLoading ? null : _sendMagicLink,
        ),
      ],
    );
  }

  Widget _buildMagicLinkSent(_AuthLayoutMetrics metrics) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: EllaColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EllaColors.info, width: 3),
          ),
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: EllaTextStyles.authBodySemibold,
                  children: [
                    const TextSpan(text: 'We have sent a link to '),
                    TextSpan(
                      text: _emailController.text,
                      style: EllaTextStyles.button.copyWith(
                        color: EllaColors.berryMain,
                        letterSpacing: 0.07,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your Inbox!',
                textAlign: TextAlign.center,
                style: EllaTextStyles.authBodySemibold,
              ),
            ],
          ),
        ),
        SizedBox(height: metrics.formGap),
        TextButton(
          onPressed: withTapClick(_resetToButtons),
          child: Text(
            'Use a Different Email',
            style: EllaTextStyles.authBodySemibold.copyWith(
              color: EllaColors.berryMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLayoutMetrics {
  const _AuthLayoutMetrics({
    required this.safeWidth,
    required this.safeHeight,
    required this.horizontalPadding,
    required this.contentWidth,
    required this.mascotSize,
    required this.topMascotInset,
    required this.loginTitleGap,
    required this.loginActionsGap,
    required this.buttonHeight,
    required this.buttonGap,
    required this.formGap,
    required this.backdropReserve,
    required this.authIconSize,
    required this.googleIconSize,
    required this.emailTitleGap,
    required this.centeredGroupGap,
  });

  final double safeWidth;
  final double safeHeight;
  final double horizontalPadding;
  final double contentWidth;
  final double mascotSize;
  final double topMascotInset;
  final double loginTitleGap;
  final double loginActionsGap;
  final double buttonHeight;
  final double buttonGap;
  final double formGap;
  final double backdropReserve;
  final double authIconSize;
  final double googleIconSize;
  final double emailTitleGap;
  final double centeredGroupGap;

  static const double maxContentWidth = 382;

  factory _AuthLayoutMetrics.from(Size safeSize) {
    final horizontalPadding = horizontalPaddingFor(safeSize.width);
    final contentWidth = math.min(
      maxContentWidth,
      math.max(0.0, safeSize.width - horizontalPadding * 2),
    );
    final shortest = safeSize.shortestSide;
    final height = safeSize.height;
    final buttonHeight = _clampDouble(height * 0.077, 56, 72);

    return _AuthLayoutMetrics(
      safeWidth: safeSize.width,
      safeHeight: safeSize.height,
      horizontalPadding: horizontalPadding,
      contentWidth: contentWidth,
      mascotSize: _clampDouble(shortest * 0.42, 132, 180),
      topMascotInset: _clampDouble(height * 0.069, 28, 64),
      loginTitleGap: _clampDouble(height * 0.026, 18, 24),
      loginActionsGap: _clampDouble(height * 0.043, 28, 40),
      buttonHeight: buttonHeight,
      buttonGap: _clampDouble(height * 0.026, 16, 24),
      formGap: _clampDouble(height * 0.026, 18, 24),
      backdropReserve: _clampDouble(height * 0.13, 88, 128),
      authIconSize: _clampDouble(buttonHeight * 0.44, 28, 32),
      googleIconSize: _clampDouble(buttonHeight * 0.56, 32, 40),
      emailTitleGap: _clampDouble(height * 0.017, 12, 16),
      centeredGroupGap: _clampDouble(height * 0.07, 44, 72),
    );
  }

  static double horizontalPaddingFor(double width) {
    return _clampDouble(width * 0.056, 16, 24);
  }

  static double backButtonInsetFor(double height) {
    return _clampDouble(height * 0.026, 16, 24);
  }
}

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

class _BackCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackCircleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('auth-back-button'),
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EllaColors.greenLight, // #DDF8E8 circle fill
            shape: BoxShape.circle,
            border: Border.all(color: EllaColors.greenDeep, width: 2),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: EllaColors.greenDeep,
          ),
        ),
      ),
    );
  }
}
