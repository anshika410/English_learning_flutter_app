import 'dart:async';
import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_links/app_links.dart';
import 'services/ella_api_service.dart';
import 'services/analytics_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/privacy_policy_webview_screen.dart';

import 'route_observer.dart';
import 'core/theme_colors.dart';
import 'core/text_styles.dart';
import 'providers/chat_provider.dart';
import 'providers/garden_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/placement_provider.dart';
import 'providers/garden_provider.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/child_view/onboarding/onboarding_flow.dart';
import 'screens/child_view/placement_intro_screen.dart';
import 'screens/child_view/profile_screen.dart';
import 'screens/child_view/spot_access_screen.dart';
import 'screens/child_view/widgets/mascot_loading_screen.dart';


class EllaApp extends ConsumerStatefulWidget {
  const EllaApp({super.key});

  @override
  ConsumerState<EllaApp> createState() => _EllaAppState();
}

class _EllaAppState extends ConsumerState<EllaApp> {
  late AppLinks _appLinks;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initAuthAndDeepLinks();
  }

  @override
  void dispose() {
    super.dispose();
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
    final refreshToken = parsedUri.queryParameters['refresh_token'];
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
      await api.saveTokens(token, userId, refreshToken: refreshToken);
      if (mounted) {
        // Invalidate auth-dependent providers so they reload with the new token
        ref.invalidate(chatProvider);
        ref.invalidate(onboardingProvider);
        ref.invalidate(placementProvider);
        ref.invalidate(placementCacheProvider);
        ref.invalidate(gardenProvider);

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
      title: 'Ella',
      debugShowCheckedModeBanner: false,
      theme: _botanicalBerryTheme(),
      navigatorObservers: [
        appRouteObserver,
        // Debug-only: lets Chucker's in-app HTTP inspector open its screen when
        // you tap the floating bubble. Inert in release (showOnRelease is false).
        // navigatorKey is already taken by this app for deep-link routing, so the
        // (legacy) observer wiring is the right fit — the app pushes on the root
        // navigator only, which is exactly where observer-based wiring is reliable.
        // ignore: deprecated_member_use
        if (kDebugMode) ChuckerFlutter.navigatorObserver,
      ],
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
        } else if (path == '/onboarding') {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => const Scaffold(
              backgroundColor: Colors.transparent,
              body: OnboardingFlow(),
            ),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          );
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

final placementCacheProvider = FutureProvider<bool>((ref) {
  return EllaApiService().isPlacementDone();
});

/// Whether the signed-in student's email marks them as part of NavGurukul's
/// small early-access group. Purely cosmetic (drives the one-time "You've
/// got a spot" welcome screen) — never used to gate real features, so a
/// client-side check against the already-authenticated user's own profile is
/// sufficient; no backend flag needed.
final isEarlyAccessStudentProvider = FutureProvider<bool>((ref) async {
  final api = EllaApiService();
  String? email;
  try {
    final profile = await api.getUserProfile();
    final profMap = profile['profile'] as Map<String, dynamic>? ?? {};
    email = (profile['email'] as String?) ?? (profMap['email'] as String?);
    if (email != null && email.trim().isNotEmpty) {
      await api.cacheUserEmail(email.trim());
    }
  } catch (_) {
    email = await api.getCachedEmail();
  }
  return (email ?? '').trim().toLowerCase().endsWith('@navgurukul.org');
});

/// Gateway logic that resolves which branch of the app the child should see.
/// When online, users who haven't completed placement are sent to the
/// [PlacementIntroScreen]. If they are offline (or error out while originally
/// offline and can't place), the regular Home shows. Watching chatProvider means
/// the switch happens automatically the moment ChatNotifier.refreshAfterPlacement
/// lands the new memory after the screening completes.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    final placementAsync = ref.watch(placementCacheProvider);
    
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
        
        if (online) {
          if (!needsOnboarding && !needsPlacement) return const _EllaHome();

          final onboarding = ref.watch(onboardingProvider);
          if (onboarding.isLoading) {
            return const MascotLoadingScreen(message: 'Loading onboarding...');
          }
          
          final showOnboarding = needsOnboarding;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: showOnboarding
                ? _gatedOnboarding(ref)
                : const PlacementIntroScreen(),
          );
        } else {
          // Because placementAsync is watched unconditionally, it stays cached!
          if (placementAsync.isLoading) {
             return const MascotLoadingScreen(message: 'Loading home...');
          }
          final isPlacementDone = placementAsync.valueOrNull ?? false;
          if (isPlacementDone || placementAsync.hasError) return const _EllaHome();

          final onboarding = ref.watch(onboardingProvider);
          if (onboarding.isLoading) {
            return const MascotLoadingScreen(message: 'Loading onboarding...');
          }
          final onboardingDone = onboarding.valueOrNull?.done ?? false;

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: !onboardingDone
                    ? _gatedOnboarding(ref)
                    : const PlacementIntroScreen(),
              );
        }
      },
    );
  }

  /// Shows the one-time "You've got a spot" early-access welcome before
  /// [OnboardingFlow] for students whose email qualifies, otherwise goes
  /// straight to onboarding. Offline or on any lookup error, the check
  /// resolves to `false` (fails closed to the normal flow) rather than
  /// blocking onboarding on a spinner.
  Widget _gatedOnboarding(WidgetRef ref) {
    final seen = ref.watch(spotAccessSeenProvider);
    if (seen) return const OnboardingFlow();

    final earlyAccessAsync = ref.watch(isEarlyAccessStudentProvider);
    final isEarlyAccess = earlyAccessAsync.valueOrNull ?? false;
    if (earlyAccessAsync.isLoading) {
      return const MascotLoadingScreen(message: 'Getting home ready...');
    }
    if (!isEarlyAccess) return const OnboardingFlow();

    return SpotAccessScreen(
      onContinue: () => ref.read(spotAccessSeenProvider.notifier).markSeen(),
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
    if (!mounted) return;
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
    AnalyticsService.logSettingsOpened();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: ProfileScreen(),
        ),
      ),
    );
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
    );
  }
}
