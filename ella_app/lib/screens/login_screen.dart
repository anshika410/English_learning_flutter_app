// Login — Figma "Onboarding / Login / Email login / Magic Link" frames.
// Shares the onboarding scenery (peach→cyan sky, hills, garden blooms) and the
// live listening Zoe mascot with the Splash screen. CTAs use the app-wide
// EllaPrimaryButton (flat fill + stamp shadow, same as the Home screen):
//   • Continue With Google — primary, Google logo in a white disc. On web the
//     platform-rendered GIS button is used instead (required for iframe auth).
//   • Continue With Email  — outline variant.
//   • Send Me a Link       — primary with the play-arrow glyph (Figma).
// Auth logic (Google Sign-In events, web One Tap, magic link) is unchanged.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../core/text_styles.dart';
import '../core/theme_colors.dart';
import '../services/audio_service.dart';
import '../services/ella_api_service.dart';
import 'child_view/widgets/ella_primary_button.dart';
import 'child_view/widgets/onboarding_scenery.dart';
import 'child_view/widgets/zoe_mascot.dart';
import 'google_sign_in_button.dart';

const String _kGoogleLogoSvg =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="20px" height="20px"><path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z"/><path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z"/><path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z"/><path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z"/></svg>''';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final EllaApiService _api = EllaApiService();

    bool _isLoading = false;
  bool _showEmailInput = false;
  bool _magicLinkSent = false;
  bool _isSigningIn = false;

  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late final StreamSubscription<gsi.GoogleSignInAuthenticationEvent>
      _googleSignInSubscription;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);

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
          } else {
            _showError('Google Login failed: no idToken.');
          }
        } catch (e) {
          _showError('Google Login Error: $e');
        } finally {
          _isSigningIn = false;
        }
      }
    });

    // Automatically prompt Google One Tap / FedCM when visiting the site (Web only)
    if (kIsWeb) {
      Future.microtask(() async {
        try {
          final lightweightAuth =
              gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
          if (lightweightAuth != null) {
            final googleUser = await lightweightAuth;
            if (googleUser != null) {
              final auth = await googleUser.authentication;
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
  void dispose() {
    _googleSignInSubscription.cancel();
    _emailFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
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
    if (_isSigningIn) return;
    _isSigningIn = true;
    setState(() => _isLoading = true);
    try {
      gsi.GoogleSignInAccount? googleUser;

      try {
        // In google_sign_in v7+, attemptLightweightAuthentication() triggers the
        // Android Credential Manager's "One-Tap" bottom sheet UI (useButtonFlow: false).
        googleUser =
            await gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
        
        if (googleUser == null) {
          // The user dismissed the bottom sheet (swiped down or went back).
          // Cancel the login flow silently.
          setState(() {
            _isLoading = false;
          });
          _isSigningIn = false;
          return;
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('cancel') || errorStr.contains('interrupted')) {
          // User cancelled the standard account picker. Quietly return.
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
      _showError('Google Sign In Error: $e');
    } finally {
      _isSigningIn = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await _api.requestMagicLink(email);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _magicLinkSent = true;
        } else {
          _showError('Failed to send magic link. Please try again.');
        }
      });
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
              // Main Scrollable Content
              SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),

                            // Listening Zoe — same native mascot animation as
                            // the Home screen.
                            ZoeMascot(
                              mode: ZoeMascotMode.listening,
                              size: 148,
                              reducedMotion:
                                  MediaQuery.of(context).disableAnimations,
                            ),

                            const SizedBox(height: 24),

                            // Keep the CTA column phone-width on web.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Column(
                                children: [
                                  if (!_magicLinkSent && !_showEmailInput)
                                    ..._buildLoginButtons()
                                  else if (_showEmailInput && !_magicLinkSent)
                                    ..._buildEmailForm()
                                  else
                                    ..._buildMagicLinkSent(),
                                ],
                              ),
                            ),

                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Back button for the email input / success states.
              if (_showEmailInput || _magicLinkSent)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: _BackCircleButton(onTap: _resetToButtons),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoginButtons() {
    return [
      Text(
        'ZoSpeak',
        style: EllaFonts.bricolage(
          const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: EllaColors.ink,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Talk More. Grow Your English',
        style: EllaTextStyles.bodySemibold.copyWith(height: 1.2),
      ),
      const SizedBox(height: 40),

      // Google Login — on web the platform-rendered GIS button must be used
      // (auth happens inside its iframe); native gets the home-style button.
      if (kIsWeb)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: getGoogleSignInButton(),
        )
      else
        EllaPrimaryButton(
          label: 'Continue With Google',
          height: 56,
          leading: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: EllaColors.onPrimary,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.string(
                    _kGoogleLogoSvg,
                    width: 20,
                    height: 20,
                  ),
                ),
          onTap: _isLoading ? null : _handleGoogleSignIn,
        ),
      const SizedBox(height: 16),

      // Email Login Button — outline variant of the same button family.
      EllaPrimaryButton(
        label: 'Continue With Email',
        height: 56,
        variant: EllaButtonVariant.outline,
        leading: const Icon(
          Icons.mail_outline_rounded,
          size: 22,
          color: EllaColors.berryDark,
        ),
        onTap: _isLoading
            ? null
            : () => setState(() => _showEmailInput = true),
      ),
      const SizedBox(height: 24),
      _PrivacyFooter(
        onReadPolicy: () => Navigator.of(context).pushNamed('/privacy-policy'),
      ),
    ];
  }

  List<Widget> _buildEmailForm() {
    return [
      Text('Sign In With Email', style: EllaTextStyles.titleSmall),
      const SizedBox(height: 12),
      Text(
        'We will send you a link. No password needed',
        style: EllaTextStyles.bodySmall.copyWith(
          color: EllaColors.textSecondary,
        ),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _emailController,
        focusNode: _emailFocusNode,
        keyboardType: TextInputType.emailAddress,
        style: EllaTextStyles.bodyBase,
        decoration: InputDecoration(
          hintText: 'Eg. xyz@gmail.com',
          hintStyle: EllaTextStyles.bodySmall.copyWith(
            color: EllaColors.textTertiary,
          ),
          filled: true,
          fillColor: EllaColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: EllaColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: EllaColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: EllaColors.berryDark,
              width: 1.5,
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      // "Send Me a Link" — primary button with the Figma play-arrow glyph.
      EllaPrimaryButton(
        label: 'Send Me a Link',
        height: 56,
        leading: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: EllaColors.onPrimary,
                  strokeWidth: 3,
                ),
              )
            : const Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: EllaColors.onPrimary,
              ),
        onTap: _isLoading ? null : _sendMagicLink,
      ),
    ];
  }

  List<Widget> _buildMagicLinkSent() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EllaColors.info, width: 1.5),
        ),
        child: Column(
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: EllaTextStyles.bodySemibold.copyWith(height: 1.5),
                children: [
                  const TextSpan(text: 'We have sent a link to '),
                  TextSpan(
                    text: _emailController.text,
                    style: const TextStyle(color: EllaColors.berryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Check your Inbox!', style: EllaTextStyles.titleSmall),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: withTapClick(_resetToButtons),
        child: Text(
          'Use a Different Email',
          style: EllaTextStyles.button.copyWith(
            fontSize: 16,
            color: EllaColors.berryDark,
          ),
        ),
      ),
    ];
  }
}

// Round back control — surface disc with a green ring, matching the Figma
// email-login / magic-link frames.
class _BackCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackCircleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: EllaColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: EllaColors.greenDark, width: 2),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: EllaColors.greenDeep,
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  final VoidCallback onReadPolicy;
  const _PrivacyFooter({required this.onReadPolicy});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Your learning data stays private and is never shared with anyone',
          textAlign: TextAlign.center,
          style: EllaTextStyles.bodySmall.copyWith(
            fontSize: 12,
            color: EllaColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onReadPolicy,
          child: Text(
            'Read Privacy Policy',
            style: EllaTextStyles.caption.copyWith(
              color: EllaColors.berryDark,
              decoration: TextDecoration.underline,
              decorationColor: EllaColors.berryDark,
            ),
          ),
        ),
      ],
    );
  }
}
