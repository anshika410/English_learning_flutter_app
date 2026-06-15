import 'package:flutter/material.dart';
import 'screens/child_view/home_screen.dart';
import 'screens/child_view/garden_screen.dart';
import 'screens/glass_box/glass_box_screen.dart';

// kShowGlassBox: flip to false before shipping to production.
// When false the bottom nav collapses to [Talk | Garden].
const bool kShowGlassBox = true;

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

class _EllaHome extends StatefulWidget {
  const _EllaHome();

  @override
  State<_EllaHome> createState() => _EllaHomeState();
}

class _EllaHomeState extends State<_EllaHome> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: kShowGlassBox ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabViews = <Widget>[
      const HomeScreen(),
      const GardenScreen(),
      if (kShowGlassBox) const GlassBoxScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      bottomNavigationBar: _EllaTabBar(controller: _tabs),
      body: TabBarView(controller: _tabs, children: tabViews),
    );
  }
}

class _EllaTabBar extends StatelessWidget {
  final TabController controller;
  const _EllaTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF388E3C),
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: Colors.white,
        tabs: [
          const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Talk'),
          const Tab(icon: Icon(Icons.local_florist_outlined), text: 'Garden'),
          if (kShowGlassBox)
            const Tab(icon: Icon(Icons.science_outlined), text: 'Glass Box'),
        ],
      ),
    );
  }
}
