import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/chat_provider.dart';
import 'screens/welcome_screen.dart';
import 'theme/ella_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EllaApp());
}

class EllaApp extends StatelessWidget {
  const EllaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        title: 'Zoe — English Tutor',
        debugShowCheckedModeBanner: false,
        theme: EllaTheme.light(),
        home: const WelcomeScreen(),
      ),
    );
  }
}
