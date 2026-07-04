import 'package:flutter/material.dart';

import 'core/theme_colors.dart';
import 'core/text_styles.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/child_view/profile_screen.dart';
import 'screens/child_view/conversation_states_preview.dart';
import 'screens/glass_box/glass_box_screen.dart';

// kShowGlassBox: flip to true to expose the Glass Box (engine testing) screen
// via a floating debug button. Hidden by default so the child-facing build shows
// only the Home / Garden / Profile surfaces.
// Flip to true to expose the debug FABs (conversation-states preview + Glass Box).
const bool kShowGlassBox = false;

class EllaApp extends StatelessWidget {
  const EllaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELLA',
      debugShowCheckedModeBanner: false,
      theme: _botanicalBerryTheme(),
      home: const _EllaHome(),
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
