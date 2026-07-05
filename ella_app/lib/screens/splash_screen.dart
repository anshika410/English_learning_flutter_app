import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/ella_api_service.dart';
import '../services/update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _listenAnim;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // match login screen speed
    )..repeat(reverse: true);
    _listenAnim = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _checkAuthAndNavigate();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Artificial delay for splash screen aesthetics
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check for in-app updates (Android only)
    await UpdateService.checkForUpdates();
    
    if (!mounted) return;
    
    final api = EllaApiService();
    final isAuthenticated = await api.isAuthenticated();
    
    if (!mounted) return;
    
    if (isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFA),
      body: Stack(
        children: [
          // Background Gradient
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
          
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _listenAnim.value,
                      child: SizedBox(
                        height: 160,
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
                const Text(
                  'ZoSpeak',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E3A),
                    fontFamily: 'Amulya',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Talk More. Grow Your English',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E3A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Re-using the landscape painter from login screen for consistency
class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hillPaint1 = Paint()
      ..color = const Color(0xFFD4F0E1)
      ..style = PaintingStyle.fill;
      
    final hillPaint2 = Paint()
      ..color = const Color(0xFFAFE0CA)
      ..style = PaintingStyle.fill;

    // Back Hill
    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(size.width * 0.3, size.height * 0.1, size.width * 0.7, size.height * 0.5);
    path1.quadraticBezierTo(size.width * 0.9, size.height * 0.7, size.width, size.height * 0.6);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, hillPaint1);

    // Front Hill
    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width, size.height * 0.7);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, hillPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
