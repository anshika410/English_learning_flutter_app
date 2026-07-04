import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'welcome_screen.dart';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _magicLinkSent = false;
  
  late final AnimationController _floatController;
  late final AnimationController _sunSpinController;

  String _currentMascot = 'assets/mascot-animations/listening.webp';

  @override
  void initState() {
    super.initState();
    // Mascot floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Sun spinning animation (very slow)
    _sunSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Listen to email field focus to change mascot state
    _emailFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus) {
      // Mascot "thinks" while you type your email
      setState(() {
        _currentMascot = 'assets/mascot-animations/regular-thinking.webp';
      });
      // Automatically scroll down so the Magic Link button isn't hidden
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else {
      // Reverts to listening when you click away
      setState(() {
        _currentMascot = 'assets/mascot-animations/listening.webp';
      });
    }
  }

  void _pokeMascot() {
    // When the user taps the mascot, it plays a fun animation!
    setState(() {
      _currentMascot = 'assets/mascot-animations/juggling.webp';
    });
    
    // Revert back after a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentMascot = _emailFocusNode.hasFocus
              ? 'assets/mascot-animations/regular-thinking.webp'
              : 'assets/mascot-animations/listening.webp';
        });
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _sunSpinController.dispose();
    _scrollController.dispose();
    _emailFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '778575174037-tg76ia7gf961rrqh8g2s3ptnnr5gkos4.apps.googleusercontent.com' : null,
        serverClientId: kIsWeb ? null : '778575174037-tg76ia7gf961rrqh8g2s3ptnnr5gkos4.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        final tokenToSend = auth.idToken ?? auth.accessToken;
        
        if (tokenToSend != null) {
          final success = await ApiService.instance.loginWithGoogle(tokenToSend);
          if (success && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            );
          } else {
            _showError('Login failed on backend');
          }
        } else {
          _showError('No authentication token received from Google.');
        }
      }
    } catch (error) {
      _showError('Google Sign-In Error: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email');
      return;
    }
    _emailFocusNode.unfocus(); // hide keyboard
    setState(() {
      _isLoading = true;
      _currentMascot = 'assets/mascot-animations/bubblepop.webp'; // happy anticipation
    });
    
    final success = await ApiService.instance.requestMagicLink(email);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _magicLinkSent = success;
        // Revert mascot
        _currentMascot = 'assets/mascot-animations/listening.webp';
      });
      if (!success) {
        _showError('Failed to send magic link');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.nunito()),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Wrap entire scaffold in a gesture detector to unfocus when tapping outside
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD9F2FF), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.6],
                ),
              ),
            ),
            
            // Spinning Sun
            Positioned(
              top: 60,
              left: 40,
              child: AnimatedBuilder(
                animation: _sunSpinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _sunSpinController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF59E0B),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Hills (Bottom)
            Positioned(
              bottom: -150,
              left: -100,
              right: -100,
              child: Container(
                height: 400,
                decoration: const BoxDecoration(
                  color: Color(0xFFAED581),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -200,
              left: -300,
              right: 100,
              child: Container(
                height: 500,
                decoration: const BoxDecoration(
                  color: Color(0xFFC5E1A5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Main Content
            SafeArea(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      // Interactive Floating Mascot
                      GestureDetector(
                        onTap: _pokeMascot,
                        child: AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, 10 * _floatController.value - 5),
                              child: child,
                            );
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            child: Image.asset(
                              _currentMascot,
                              key: ValueKey<String>(_currentMascot),
                              height: 140,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Main Card
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFF81D4FA), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF81D4FA).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome to Ella!',
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3A8A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
                            else if (_magicLinkSent)
                              _buildMagicLinkSentUI()
                            else
                              _buildLoginUI(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
}

  Widget _buildMagicLinkSentUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFD1FAE5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFF10B981)),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your email!',
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a magic link to\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 16, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => setState(() => _magicLinkSent = false),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFEC4899),
            textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Use a different email'),
        )
      ],
    );
  }

  Widget _buildLoginUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3D Style Google Button
        _build3DButton(
          text: 'Sign in with Google',
          color: const Color(0xFFEC4899),
          shadowColor: const Color(0xFFBE185D),
          onPressed: _handleGoogleSignIn,
        ),
        const SizedBox(height: 28),
        
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR EMAIL',
                style: GoogleFonts.nunito(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 2)),
          ],
        ),
        const SizedBox(height: 28),
        
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A)),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF81D4FA), width: 2),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _handleMagicLink(),
        ),
        const SizedBox(height: 16),
        
        // 3D Style Magic Link Button
        _build3DButton(
          text: 'Send Magic Link',
          color: const Color(0xFFF59E0B),
          shadowColor: const Color(0xFFD97706),
          onPressed: _handleMagicLink,
        ),
      ],
    );
  }

  Widget _build3DButton({
    required String text,
    required Color color,
    required Color shadowColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
