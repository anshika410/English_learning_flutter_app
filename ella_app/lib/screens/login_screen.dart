// Login — Figma "Onboarding / Login / Email login / Magic Link" frames.
// Figma provides visual proportions and assets; layout is responsive so the
// screens hold up across short, tall, narrow, and high-density phones.
// Auth logic (Google Sign-In events, web One Tap, magic link) is unchanged.

import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsi_all;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../core/app_toast.dart';
import '../providers/chat_provider.dart';
import '../providers/connectivity_provider.dart';
import '../core/text_styles.dart';
import '../core/theme_colors.dart';
import '../core/offline_alert_popup.dart';
import '../services/audio_service.dart';
import '../services/ella_api_service.dart';
import 'child_view/widgets/ella_primary_button.dart';
import 'child_view/widgets/onboarding_scenery.dart';
import 'child_view/widgets/zoe_mascot.dart';
import 'google_sign_in_button.dart';

const String _kGoogleLoginAsset = 'assets/auth/google-login.svg';
const String _kEnvelopeOpenAsset = 'assets/auth/envelope-open.svg';
const String _kPaperPlaneRightAsset = 'assets/auth/paper-plane-right.svg';
const String _kShieldCheckAsset = 'assets/auth/shield-check.svg';

class LoginScreen extends ConsumerStatefulWidget {
  final EllaApiService? api;

  /// Kept true in production. Tests can disable plugin-backed Google listeners
  /// while still exercising email and magic-link UI states.
  final bool enableGoogleAuth;

  const LoginScreen({super.key, this.api, this.enableGoogleAuth = true});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final EllaApiService _api;

  bool _isLoading = false;
  bool _showEmailInput = false;
  bool _magicLinkSent = false;
  bool _isSigningIn = false;

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

  StreamSubscription<gsi.GoogleSignInAuthenticationEvent>?
  _googleSignInSubscription;
  Timer? _magicLinkPollTimer;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? EllaApiService();

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
        if (_isSigningIn) return;
        _isSigningIn = true;
        final account = event.user;
        try {
          final gsi.GoogleSignInAuthentication googleAuth =
              account.authentication;
          final String? idToken = googleAuth.idToken;
          if (idToken != null) {
            final success = await _api.loginWithGoogle(idToken);
            if (success && mounted) {
              ref.invalidate(chatProvider);
              Navigator.of(context).pushReplacementNamed('/');
            } else {
              _showError('Google Login failed on backend.');
            }
          }
        } catch (e) {
          _showError('Google Login Error: $e');
        } finally {
          _isSigningIn = false;
        }
      }
    }, onError: (error, stackTrace) {
      debugPrint('[Login] authenticationEvents stream error ignored: $error');
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
                if (_isSigningIn) return;
                _isSigningIn = true;
                try {
                  final success = await _api.loginWithGoogle(idToken);
                  if (success && mounted) {
                    ref.invalidate(chatProvider);
                    Navigator.of(context).pushReplacementNamed('/');
                  } else {
                    _showError('One Tap Login failed on backend.');
                  }
                } finally {
                  _isSigningIn = false;
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
    _magicLinkPollTimer?.cancel();
    _introController.dispose();
    _googleSignInSubscription?.cancel();
    _emailFocusNode.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      showEllaErrorToast(context, 'Google Sign-In is not supported on Windows. Please log in via Email.');
      return;
    }

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    if (_isSigningIn) return;
    _isSigningIn = true;
    setState(() => _isLoading = true);
    try {
      if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
        final clientId = dotenv.env['GOOGLE_CLIENT_ID'];
        final clientSecret = dotenv.env['GOOGLE_CLIENT_SECRET'];
        if (clientId == null || clientSecret == null) {
          throw Exception('Google Client ID/Secret not found in .env');
        }
        final googleSignIn = gsi_all.GoogleSignIn(
          params: gsi_all.GoogleSignInParams(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectPort: 3000,
          ),
        );
        final credentials = await googleSignIn.signIn();
        if (credentials == null) {
          if (mounted) setState(() => _isLoading = false);
          _isSigningIn = false;
          return;
        }
        final success = await _api.loginWithGoogle(credentials.accessToken);
        if (success && mounted) {
          ref.invalidate(chatProvider);
          Navigator.of(context).pushReplacementNamed('/');
        } else {
          _showError('Google login failed on backend.');
        }
        return;
      }

      gsi.GoogleSignInAccount? googleUser;

      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          try {
            // Android Credential Manager "One-Tap" bottom sheet
            googleUser =
                await gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
          } catch (e) {
            // Fallback to standard sign-in if Android lightweight auth fails
            googleUser = await gsi.GoogleSignIn.instance.authenticate();
          }
        } else {
          // Cross-platform standard Google sign-in (iOS, macOS, Web)
          googleUser = await gsi.GoogleSignIn.instance.authenticate();
        }

        if (googleUser == null) {
          // User cancelled or dismissed the sign-in prompt.
          if (mounted) setState(() => _isLoading = false);
          _isSigningIn = false;
          return;
        }
      } catch (e) {
        if (e is gsi.GoogleSignInException &&
            (e.code == gsi.GoogleSignInExceptionCode.canceled ||
             e.code == gsi.GoogleSignInExceptionCode.interrupted)) {
          if (mounted) setState(() => _isLoading = false);
          _isSigningIn = false;
          return;
        }
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('cancel') || errorStr.contains('interrupted')) {
          if (mounted) setState(() => _isLoading = false);
          _isSigningIn = false;
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
          ref.invalidate(chatProvider);
          // Restart app to pick up auth state
          Navigator.of(context).pushReplacementNamed('/');
        } else {
          _showError('Google login failed on backend.');
        }
      }
    } catch (e) {
      if (e is gsi.GoogleSignInException &&
          (e.code == gsi.GoogleSignInExceptionCode.canceled ||
           e.code == gsi.GoogleSignInExceptionCode.interrupted)) {
        // User cancelled sign in. Quietly ignore.
      } else {
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('cancel') && !errorStr.contains('interrupted')) {
          _showError('Google Sign In Error: $e');
        }
      }
    } finally {
      _isSigningIn = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMagicLink() async {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      // Input-validation feedback keeps its own specific copy (not a server error).
      showEllaErrorToast(context, 'Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await _api.requestMagicLink(email);
    if (!mounted) return;

    // If the user dismissed the email input while the request was in flight, discard the result
    if (!_showEmailInput) return;

    setState(() {
      _isLoading = false;
      _magicLinkSent = success;
    });
    if (success) {
      _startMagicLinkPolling(email);
    } else {
      _showError('Failed to send magic link. Please try again.');
    }
  }

  void _startMagicLinkPolling(String email) {
    _magicLinkPollTimer?.cancel();
    _magicLinkPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || !_magicLinkSent) {
        timer.cancel();
        return;
      }
      final success = await _api.checkMagicLinkStatus(email);
      if (success && mounted) {
        timer.cancel();
        ref.invalidate(chatProvider);
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }

  // Any Google / One-Tap / magic-link backend or network failure surfaces the
  // one standard server-error toast — the descriptive [debug] string is logged
  // only, never shown to the user.
  void _showError(String debug) {
    if (!mounted) return;
    debugPrint('[Login] $debug');
    final userMessage = debug.toLowerCase().contains('magic link')
        ? 'Failed to send magic link. Please try again.'
        : 'Failed to log in. Please try again.';
    showEllaErrorToast(context, userMessage);
  }

  void _resetToButtons() {
    _magicLinkPollTimer?.cancel();
    setState(() {
      _magicLinkSent = false;
      _showEmailInput = false;
      _isLoading = false;
      _emailController.clear();
    });
  }

  void _resetToEmailInput() {
    _magicLinkPollTimer?.cancel();
    setState(() {
      _magicLinkSent = false;
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
        // Don't resize the body when the keyboard opens: the email stage stays
        // fixed (mascot + title + field + button all hold their positions)
        // instead of the form re-centring/shifting up as the keyboard appears.
        resizeToAvoidBottomInset: false,
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
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: metrics.safeHeight,
            maxWidth: metrics.contentWidth,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  child: Column(
                    children: [
                      Text(
                        'Ella',
                        textAlign: TextAlign.center,
                        style: EllaTextStyles.authDisplay,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Speak More. Grow your English.',
                        textAlign: TextAlign.center,
                        style: EllaTextStyles.authTitle,
                      ),
                      SizedBox(height: metrics.loginActionsGap),
                      _buildLoginButtons(metrics),
                      SizedBox(height: metrics.buttonGap),
                      _buildPrivacyNote(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: metrics.backdropReserve),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredStage({
    required BuildContext context,
    required _AuthLayoutMetrics metrics,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: metrics.safeHeight,
            maxWidth: metrics.contentWidth,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: metrics.topMascotInset),
              _buildMascot(metrics),
              SizedBox(height: metrics.loginTitleGap),
              child,
              SizedBox(height: metrics.backdropReserve),
            ],
          ),
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
            label: 'Continue with Google',
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
          label: 'Continue with Email',
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

  // Privacy reassurance under the login buttons (Figma 441:26073): shield icon +
  // body copy, left-aligned.
  Widget _buildPrivacyNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(_kShieldCheckAsset, width: 32, height: 32),
        const SizedBox(width: 12),
        Text(
          'Your learning data is protected.',
          style: EllaTextStyles.authBody.copyWith(fontSize: 15),
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
          'Sign in with Email',
          textAlign: TextAlign.center,
          style: EllaTextStyles.authTitle,
        ),
        SizedBox(height: metrics.emailTitleGap),
        Text(
          "We'll email you a sign-in link. No password needed",
          textAlign: TextAlign.center,
          style: EllaTextStyles.authBody,
        ),
        SizedBox(height: metrics.formGap),
        SizedBox(
          height: 72,
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textAlignVertical: TextAlignVertical.center,
            style: EllaTextStyles.authBody,
            decoration: InputDecoration(
              hintText: 'name@example.com',
              hintStyle: EllaTextStyles.authBody.copyWith(
                color: EllaColors.textTertiary,
              ),
              filled: true,
              fillColor: EllaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          label: 'Send Sign-In Link',
          height: 72,
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
                    TextSpan(text: 'We sent a sign-in link to ${_emailController.text}.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: withTapClick(() async {
                  if (Platform.isAndroid) {
                    const intent = AndroidIntent(
                      action: 'android.intent.action.MAIN',
                      category: 'android.intent.category.APP_EMAIL',
                    );
                    try {
                      await intent.launch();
                    } catch (_) {
                      if (mounted) showEllaErrorToast(context, 'No email app found. Open your email in a browser');
                    }
                  } else if (Platform.isIOS) {
                    final url = Uri(scheme: 'message');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (mounted) showEllaErrorToast(context, 'No email app found. Open your email in a browser');
                    }
                  }
                }),
                child: Text(
                  'Open Email App',
                  textAlign: TextAlign.center,
                  style: EllaTextStyles.authBodySemibold.copyWith(
                    color: EllaColors.berryMain,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: metrics.formGap),
        TextButton(
          onPressed: withTapClick(_resetToEmailInput),
          child: Text(
            'Use Another Email',
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
            color: EllaColors.surface, // Changed from greenLight to surface
            shape: BoxShape.circle,
            border: Border.all(color: EllaColors.greenDeep, width: 2),
            boxShadow: const [
              BoxShadow(
                color: EllaColors.greenDeep,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
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
