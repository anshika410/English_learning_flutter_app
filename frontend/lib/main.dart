import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'mock/mock_config.dart';
import 'providers/chat_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'services/user_prefs_service.dart';
import 'services/api_service.dart';
import 'theme/ella_theme.dart';

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

  // Authenticate with backend (silent, non-blocking on failure)
  ApiService.instance.ensureAuthenticated().ignore();

  // Check if user has already completed onboarding/placement
  final prefs = UserPrefsService();
  await prefs.init();
  final bool hasCompletedPlacement = prefs.hasCompletedPlacement;

  runApp(EllaApp(skipOnboarding: hasCompletedPlacement));
}

class EllaApp extends StatelessWidget {
  final bool skipOnboarding;

  const EllaApp({super.key, this.skipOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(llm: createLlmService()),
      child: MaterialApp(
        title: 'Zoe — English Tutor',
        debugShowCheckedModeBanner: false,
        theme: EllaTheme.light(),
        home: skipOnboarding ? const HomeScreen() : const WelcomeScreen(),
      ),
    );
  }
}


