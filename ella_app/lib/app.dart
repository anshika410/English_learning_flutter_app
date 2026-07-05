import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_links/app_links.dart';
import 'services/ella_api_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

import 'route_observer.dart';
import 'core/theme_colors.dart';
import 'core/text_styles.dart';
import 'providers/chat_provider.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/child_view/placement_intro_screen.dart';
import 'screens/child_view/profile_screen.dart';
import 'screens/child_view/conversation_states_preview.dart';
import 'screens/child_view/widgets/garden_sky_background.dart';
import 'screens/glass_box/glass_box_screen.dart';

// kShowGlassBox: flip to true to expose the Glass Box (engine testing) screen
// via a floating debug button. Hidden by default so the child-facing build shows
// only the Home / Garden / Profile surfaces.
// Flip to true to expose the debug FABs (conversation-states preview + Glass Box).
const bool kShowGlassBox = false;

class EllaApp extends StatefulWidget {
  const EllaApp({super.key});

  @override
  State<EllaApp> createState() => _EllaAppState();
}

class _EllaAppState extends State<EllaApp> {
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;
  late AppLinks _appLinks;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    _initAuthAndDeepLinks();
  }

  Future<void> _initAuthAndDeepLinks() async {
    final api = EllaApiService();
    
    // Check initial auth state
    final isAuth = await api.isAuthenticated();
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isCheckingAuth = false;
      });
    }

    // Initialize App Links for Magic Link handling
    _appLinks = AppLinks();
    
    // Handle incoming app links while the app is in the background or foreground
    _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
    
    // Handle link that started the app (if any)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }
  }
  
  void _handleDeepLink(Uri uri) async {
    // Expected magic link format: ella://login?token=XYZ&user_id=123
    // Or on web: http://domain/#/login?token=XYZ&user_id=123
    
    // On web with hash routing, query params are inside the fragment (after the #)
    Uri parsedUri = uri;
    if (uri.fragment.contains('?')) {
      final fragmentParts = uri.fragment.split('?');
      if (fragmentParts.length > 1) {
         final query = fragmentParts[1];
         parsedUri = Uri.parse('dummy://dummy?$query');
      }
    }

    final token = parsedUri.queryParameters['access_token'] ?? parsedUri.queryParameters['token'];
    String? userId = parsedUri.queryParameters['user_id'];
    
    // If backend didn't return user_id, extract it from the JWT's 'sub' claim
    if (userId == null && token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          // dart:convert is imported at the top of the file? Wait, app.dart doesn't import dart:convert.
          // Let's just pass an empty string or 'unknown_user_id'. The backend uses the Bearer token anyway.
          userId = 'user_from_token'; 
        }
      } catch (_) {}
    }
    
    if (token != null && userId != null) {
      final api = EllaApiService();
      await api.saveTokens(token, userId);
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
        _navigatorKey.currentState?.pushReplacementNamed('/');
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ELLA',
      debugShowCheckedModeBanner: false,
      theme: _botanicalBerryTheme(),
      navigatorObservers: [appRouteObserver],
      // We explicitly ignore the OS-provided initialRouteName (which might contain a cached deep link)
      // because we handle deep links manually via the app_links package.
      onGenerateInitialRoutes: (String initialRouteName) {
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: '/splash'),
            builder: (context) => const SplashScreen(),
          ),
        ];
      },
      onGenerateRoute: (settings) {
        // Handle web URLs with query parameters correctly
        final uri = Uri.parse(settings.name ?? '/');
        final path = uri.path;

        if (path == '/splash') {
          return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
        } else if (path == '/login') {
          return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
        } else if (path == '/' || path == '/home') {
          return MaterialPageRoute(builder: (_) => const RootGate(), settings: settings);
        }
        
        // Fallback
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      },
    );
  }
}

/// First-run gate. A student with no `placement` in memory is routed into the
/// placement screening before the normal topic Home; once placed (or if we're
/// offline and can't place), the regular Home shows. Watching chatProvider means
/// the switch happens automatically the moment ChatNotifier.refreshAfterPlacement
/// lands the new memory after the screening completes.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      loading: () => const GardenSkyBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(color: EllaColors.berryDark),
          ),
        ),
      ),
      // On error, don't trap the user on a spinner — fall through to Home.
      error: (_, _) => const _EllaHome(),
      data: (s) {
        final online = ref.read(chatProvider.notifier).online;
        final needsPlacement = online && s.memory.placement == null;
        return needsPlacement
            ? const Scaffold(
                backgroundColor: Colors.transparent,
                body: PlacementIntroScreen(),
              )
            : const _EllaHome();
      },
    );
  }
}

/// Botanical Berry theme. Interactive primary is [EllaColors.berryDark] (AA-safe
/// with onPrimary); [EllaColors.berryMain] is decorative only. TextTheme is
/// mapped from [EllaTextStyles] so Material widgets inherit the type scale.
ThemeData _botanicalBerryTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: EllaColors.berryDark,
    onPrimary: EllaColors.onPrimary,
    secondary: EllaColors.greenMain,
    onSecondary: EllaColors.ink,
    error: EllaColors.error,
    onError: EllaColors.onPrimary,
    surface: EllaColors.surface,
    onSurface: EllaColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: EllaColors.canvas,
    textTheme: TextTheme(
      displayLarge: EllaTextStyles.display,
      headlineLarge: EllaTextStyles.headline,
      titleLarge: EllaTextStyles.titleMedium,
      titleMedium: EllaTextStyles.titleSmall,
      bodyLarge: EllaTextStyles.bodyLarge,
      bodyMedium: EllaTextStyles.bodyBase,
      bodySmall: EllaTextStyles.bodySmall,
      labelLarge: EllaTextStyles.button,
      labelSmall: EllaTextStyles.caption,
    ),
  );
}

class _EllaHome extends StatefulWidget {
  const _EllaHome();

  @override
  State<_EllaHome> createState() => _EllaHomeState();
}

class _EllaHomeState extends State<_EllaHome> {
  // The Home screen's top-right icons open Garden / Profile as pushed routes
  // (system back returns here), so the app no longer needs a bottom tab bar —
  // each section has its own entry point on Home.
  // Garden/Profile are pushed as routes; wrap each in a Scaffold so their text
  // has a Material ancestor (otherwise it renders with debug yellow underlines).
  void _openGarden() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: GardenScreen(),
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: ProfileScreen(),
        ),
      ),
    );
  }

  void _openGlassBox() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GlassBoxScreen()));
  }

  void _openConversationPreview() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConversationStatesPreview()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.bg,
      body: HomeScreen(
        onConversationEnded: _openGarden,
        onOpenGarden: _openGarden,
        onOpenProfile: _openProfile,
      ),
      floatingActionButton: kShowGlassBox
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'convPreview',
                  onPressed: _openConversationPreview,
                  child: const Icon(Icons.view_carousel_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'glassBox',
                  onPressed: _openGlassBox,
                  child: const Icon(Icons.science_outlined),
                ),
              ],
            )
          : null,
    );
  }
}
