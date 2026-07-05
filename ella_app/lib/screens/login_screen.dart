import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import '../services/ella_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final EllaApiService _api = EllaApiService();
  
  bool _isLoading = false;
  bool _showEmailInput = false;
  bool _magicLinkSent = false;
  
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animController;
  late Animation<double> _listenAnim;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // slower for a natural, relaxed feel
    )..repeat(reverse: true);
    
    // Subtle rotation for a natural breathing/rocking feel
    _listenAnim = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
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
    setState(() => _isLoading = true);
    try {
      gsi.GoogleSignInAccount? googleUser;
      
      // Try the seamless Credential Manager (One Tap) first
      final lightweightAuth = gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
      if (lightweightAuth != null) {
        try {
          googleUser = await lightweightAuth;
          if (googleUser == null) {
            // User likely cancelled (e.g., swiped down). Do not fallback.
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        } catch (e) {
          // Throws if user cancels/closes the bottom sheet. Do not fallback.
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      } else {
        // If it isn't supported by the OS, fallback to full interactive sign in
        googleUser = await gsi.GoogleSignIn.instance.authenticate();
      }

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final gsi.GoogleSignInAuthentication googleAuth = googleUser.authentication;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFA),
      body: Stack(
        children: [
          // Background Gradient (Peach to Cyan)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFEDDF), // Soft Peach
                    Color(0xFFE5F9F6), // Light Cyan/Blue
                  ],
                  stops: [0.0, 0.4],
                ),
              ),
            ),
          ),
          
          // Hills & Flowers Landscape
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _LandscapePainter(),
              ),
            ),
          ),
          
          // Back Button
          if (_showEmailInput || _magicLinkSent)
            Positioned(
              top: 0,
              left: 20,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showEmailInput = false;
                        _magicLinkSent = false;
                        _emailController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C3E3A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),

          // Main Scrollable Content
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
                        const Spacer(),
                        
                        // Mascot Image (Zoe / Sprout)
                        AnimatedBuilder(
                          animation: _listenAnim,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _listenAnim.value,
                              child: SizedBox(
                                height: 140,
                                child: SvgPicture.asset(
                                  'assets/homescreen/new/mascot-open.svg',
                                  placeholderBuilder: (context) => const Icon(
                                    Icons.eco, size: 100, color: Color(0xFF88D9C0)
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        if (!_magicLinkSent) ...[
                          const Text(
                            'ZoSpeak',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2C3E3A),
                              fontFamily: 'Amulya',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Talk More. Grow Your English',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E3A),
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          if (!_showEmailInput) ...[
                            // Google Login Button
                            _buildButton(
                              text: 'Continue With Google',
                              color: const Color(0xFFE54E87),
                              textColor: Colors.white,
                              iconWidget: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.string(
                                  '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="20px" height="20px"><path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z"/><path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z"/><path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z"/><path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z"/></svg>''',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 16),
                            
                            // Email Login Button
                            _buildButton(
                              text: 'Continue With Email',
                              color: Colors.white,
                              textColor: const Color(0xFFE54E87),
                              border: Border.all(color: const Color(0xFF6B1B3D), width: 2),
                              iconWidget: const Icon(Icons.mail_outline, color: Color(0xFFE54E87)),
                              onPressed: () {
                                setState(() {
                                  _showEmailInput = true;
                                });
                              },
                            ),
                          ] else ...[
                            // Email Input State
                            const Text(
                              'Sign In With Email',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2C3E3A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'We will send you a link. No password needed',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4A5D58),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Eg. xyz@gmail.com',
                                hintStyle: const TextStyle(color: Color(0xFF9AA8A4), fontSize: 14),
                                filled: true,
                                fillColor: const Color(0xFFFFFDF5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFEAE5D9), width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFEAE5D9), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFE54E87), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildButton(
                              text: 'Send Me a Link',
                              color: const Color(0xFFE54E87),
                              textColor: Colors.white,
                              border: Border.all(color: const Color(0xFF6B1B3D), width: 2),
                              iconWidget: const Icon(Icons.send, color: Colors.white, size: 20),
                              onPressed: _isLoading ? null : _sendMagicLink,
                              isLoading: _isLoading,
                            ),
                          ],
                        ] else ...[
                          // Magic Link Success State
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF5A9BB1), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E3A),
                                      height: 1.5,
                                    ),
                                    children: [
                                      const TextSpan(text: 'We have sent a link to '),
                                      TextSpan(
                                        text: _emailController.text,
                                        style: const TextStyle(color: Color(0xFFE54E87)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Check your Inbox!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2C3E3A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _magicLinkSent = false;
                                _showEmailInput = false;
                                _emailController.clear();
                              });
                            },
                            child: const Text(
                              'Use a Different Email',
                              style: TextStyle(
                                color: Color(0xFFE54E87),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        
                        const Spacer(),
                        
                        // Footer
                        if (!_magicLinkSent && !_showEmailInput)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2, right: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7CD4A9),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Your learning data stays private and is never shared with anyone',
                                    style: TextStyle(
                                      color: Color(0xFF4A5D58),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
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
          
          // Back Button for Success Screen
          if (_magicLinkSent)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _magicLinkSent = false;
                    _showEmailInput = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C3E3A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required Color textColor,
    VoidCallback? onPressed,
    Widget? iconWidget,
    BoxBorder? border,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        border: border ?? Border.all(color: const Color(0xFF6B1B3D), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 0, // Flat shadow for a cartoony look
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isLoading 
              ? [
                  SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(
                      color: textColor,
                      strokeWidth: 3,
                    ),
                  ),
                ]
              : [
                  if (iconWidget != null) ...[
                    iconWidget,
                    const SizedBox(width: 12),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Amulya',
                    ),
                  ),
                ],
          ),
        ),
      ),
    );
  }
}

// Painter to draw the rolling green hills and flowers from the reference image
class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Back hill (lightest green)
    paint.color = const Color(0xFFD6EFD2);
    final path1 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.4, size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, paint);
    
    // Front hill (vibrant green)
    paint.color = const Color(0xFFA5D166);
    final path2 = Path()
      ..moveTo(0, size.height * 0.9)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint);
    
    // Draw simple flowers
    _drawFlower(canvas, Offset(size.width * 0.15, size.height * 0.5), const Color(0xFFFAC45E)); // Yellow flower
    _drawFlower(canvas, Offset(size.width * 0.8, size.height * 0.3), const Color(0xFFA485E9)); // Purple flower
    _drawFlower(canvas, Offset(size.width * 0.92, size.height * 0.4), const Color(0xFFF995B9)); // Pink flower
  }

  void _drawFlower(Canvas canvas, Offset center, Color color) {
    // Stem
    final paint = Paint()
      ..color = const Color(0xFF75B14B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    // Shadow under stem
    final shadowPaint = Paint()..color = const Color(0x33000000)..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy + 60), width: 24, height: 8), shadowPaint);
    
    canvas.drawLine(center, Offset(center.dx, center.dy + 60), paint);
    
    // Leaves
    canvas.drawLine(Offset(center.dx, center.dy + 30), Offset(center.dx - 12, center.dy + 20), paint);
    canvas.drawLine(Offset(center.dx, center.dy + 45), Offset(center.dx + 12, center.dy + 35), paint);
    
    // Petals
    final petalPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(center.dx + 8 * (i % 2 == 0 ? 1 : -1) * (i < 2 ? 1 : 0), center.dy + 8 * (i % 2 == 0 ? -1 : 1) * (i > 2 ? 1 : 0)),
        6,
        petalPaint,
      );
    }
    canvas.drawCircle(center, 8, petalPaint); // Main body
    
    // Inner center
    final centerPaint = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
