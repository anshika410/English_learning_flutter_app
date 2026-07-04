import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/chat_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/user_prefs_service.dart';
import 'services/api_service.dart';
import 'theme/ella_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

void _handleDeepLink(Uri uri) async {
  String? accessToken = uri.queryParameters['access_token'];
  String? refreshToken = uri.queryParameters['refresh_token'];
  if (accessToken != null && accessToken.isNotEmpty) {
     await ApiService.instance.saveTokensFromMagicLink(accessToken, refreshToken);
     main(); // Restart the app state after login
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env gracefully — may not exist in web deployments
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not found (e.g. web deployment) — LlmService will use empty keys
    // and fall back gracefully
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    // Check tokens from URL if running on web (after magic link verify)
    String? accessToken = Uri.base.queryParameters['access_token'];
    String? refreshToken = Uri.base.queryParameters['refresh_token'];
    if (accessToken != null && accessToken.isNotEmpty) {
       await ApiService.instance.saveTokensFromMagicLink(accessToken, refreshToken);
    }
  } else {
    // Setup App Links for mobile deep linking
    final appLinks = AppLinks();
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) _handleDeepLink(initialUri);
    } catch (_) {}
    
    appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  // Authenticate with backend
  bool isAuthenticated = await ApiService.instance.ensureAuthenticated();

  // Check if user has already completed onboarding/placement
  final prefs = UserPrefsService();
  await prefs.init();
  final bool hasCompletedPlacement = prefs.hasCompletedPlacement;

  runApp(EllaApp(
    skipOnboarding: hasCompletedPlacement,
    isAuthenticated: isAuthenticated,
  ));
}

class EllaApp extends StatelessWidget {
  final bool skipOnboarding;
  final bool isAuthenticated;

  const EllaApp({super.key, this.skipOnboarding = false, this.isAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        title: 'Zoe — English Tutor',
        debugShowCheckedModeBanner: false,
        theme: EllaTheme.light(),
        home: !isAuthenticated 
            ? const LoginScreen() 
            : (skipOnboarding ? const HomeScreen() : const WelcomeScreen()),
      ),
    );
  }
}


