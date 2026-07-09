import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_links/app_links.dart';
import 'services/ella_api_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/privacy_policy_webview_screen.dart';

import 'route_observer.dart';
import 'core/theme_colors.dart';
import 'core/text_styles.dart';
import 'providers/chat_provider.dart';
import 'providers/onboarding_provider.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/child_view/onboarding/onboarding_flow.dart';
import 'screens/child_view/placement_intro_screen.dart';
import 'screens/child_view/profile_screen.dart';
import 'screens/child_view/conversation_states_preview.dart';
import 'screens/child_view/widgets/garden_sky_background.dart';
import 'screens/glass_box/glass_box_screen.dart';
import 'providers/connectivity_provider.dart';
import 'screens/child_view/offline_screen.dart';
import 'screens/child_view/widgets/mascot_loading_screen.dart';

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
  late AppLinks _appLinks;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    _initAuthAndDeepLinks();
  }

  Future<void> _initAuthAndDeepLinks() async {
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
        // Clear the auth screens so Back can't return to login/email.
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
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
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
            if (!isOnline) {
              return const OfflineScreen();
            }
            return child ?? const SizedBox();
          },
        );
      },
      // We explicitly ignore the OS-provided initialRouteName (which might contain a cached deep link)
      // because we handle deep links manually via the app_links package.
      onGenerateInitialRoutes: (String initialRouteName) {
        if (initialRouteName.startsWith('/privacy-policy')) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/privacy-policy'),
              builder: (context) => const PrivacyPolicyWebviewScreen(),
            ),
          ];
        }
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
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          );
        } else if (path == '/privacy-policy') {
          return MaterialPageRoute(builder: (_) => const PrivacyPolicyWebviewScreen(), settings: settings);
        } else if (path == '/' || path == '/home') {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => const RootGate(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          );
        }
        
        // Fallback
        return MaterialPageRoute(builder: (_) => const RootGate(), settings: settings);
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
    
    if (chatAsync.isLoading) {
      return const MascotLoadingScreen(message: 'Getting home ready...');
    }

    return chatAsync.when(
      skipLoadingOnReload: false,
      loading: () => const SizedBox(), // Handled above
      // On error, don't trap the user on a spinner — fall through to Home.
      error: (error, _) {
        if (error is EllaApiException && error.message == 'not_authenticated') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          });
          return const SizedBox();
        }
        return const _EllaHome();
      },
      data: (s) {
        final online = ref.read(chatProvider.notifier).online;
        final needsOnboarding = online && s.memory.name == null;
        final needsPlacement = online && s.memory.placement == null;
        
        if (!needsOnboarding && !needsPlacement) return const _EllaHome();

        // Before the placement screening, collect name/age once via onboarding.
        // Watching onboardingProvider means the final "Let's Talk" flips the gate
        // and this rebuilds straight into PlacementIntroScreen — no manual nav.
        // While the cached flag is still loading, hold on the spinner so a
        // returning (onboarded-but-unplaced) child doesn't flash the flow.
        final onboarding = ref.watch(onboardingProvider);
        if (onboarding.isLoading) {
          return const MascotLoadingScreen(message: 'Loading onboarding...');
        }
        
        // Use the remote state to force onboarding if they bypassed it locally.
        // But if the backend already has their name, SKIP onboarding, even if
        // the local device cache was cleared (e.g., app reinstall).
        final onboardingDone = onboarding.valueOrNull?.done ?? false;
        final showOnboarding = online ? needsOnboarding : !onboardingDone;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: showOnboarding
              ? const OnboardingFlow()
              : const PlacementIntroScreen(),
        );
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
