import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/theme_colors.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/child_view/profile_screen.dart';
import 'screens/glass_box/glass_box_screen.dart';

// kShowGlassBox: flip to true to expose the Glass Box (engine testing) tab.
// Hidden by default so the bottom nav matches the Figma [Talk | My Garden | Profile].
const bool kShowGlassBox = false;

class EllaApp extends StatelessWidget {
  const EllaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELLA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const _EllaHome(),
    );
  }
}

class _NavItem {
  final String label;
  final String? svgAsset;
  final IconData? icon;
  final Widget screen;
  _NavItem({
    required this.label,
    this.svgAsset,
    this.icon,
    required this.screen,
  });
}

class _EllaHome extends StatefulWidget {
  const _EllaHome();

  @override
  State<_EllaHome> createState() => _EllaHomeState();
}

class _EllaHomeState extends State<_EllaHome> {
  int _index = 0;

  void _openGarden() => setState(() => _index = 1);

  late final List<_NavItem> _items = [
    _NavItem(
      label: 'Talk',
      svgAsset: 'assets/bottom_tab/to-chat-with-svgrepo-com.svg',
      screen: HomeScreen(onConversationEnded: _openGarden),
    ),
    _NavItem(
      label: 'My Garden',
      svgAsset: 'assets/bottom_tab/tree-svgrepo-com.svg',
      screen: GardenScreen(onConversationEnded: _openGarden),
    ),
    _NavItem(
      label: 'Profile',
      svgAsset: 'assets/bottom_tab/profile-svgrepo-com.svg',
      screen: const ProfileScreen(),
    ),
    if (kShowGlassBox)
      _NavItem(
        label: 'Glass Box',
        icon: Icons.science_outlined,
        screen: const GlassBoxScreen(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.bg,
      body: IndexedStack(
        index: _index,
        children: [for (final item in _items) item.screen],
      ),
      bottomNavigationBar: _EllaBottomNav(
        items: _items,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _EllaBottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  const _EllaBottomNav({
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 88,
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWidth = item.label.length > 6 ? 104.0 : 56.0;
    final iconWidget = item.svgAsset != null
        ? SvgPicture.asset(item.svgAsset!, width: 26, height: 26)
        : Icon(item.icon,
            size: 26,
            color: selected ? EllaColors.mangoDark : EllaColors.muted);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: selected ? selectedWidth : 64,
              height: selected ? 56 : 58,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: selected ? EllaColors.navSelected : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: selected ? 11 : 10.5,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w700,
                      color: selected ? Colors.white : EllaColors.primary,
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
}
