import 'package:flutter/material.dart';
import 'screens/child_view/child_chat_screen.dart';
import 'screens/glass_box/glass_box_screen.dart';

// kShowGlassBox: flip to false before shipping to production.
// Phase 6 will fill in the Glass Box tab content.
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
    _tabs = TabController(length: kShowGlassBox ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sky → grass gradient background (matches android prototype spec)
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF87CEEB), // sky blue
            Color(0xFF4CAF50), // grass green
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: kShowGlassBox
            ? _GlassTabBar(controller: _tabs)
            : null,
        body: kShowGlassBox
            ? TabBarView(
                controller: _tabs,
                children: const [
                  ChildChatScreen(),
                  GlassBoxScreen(),
                ],
              )
            : const ChildChatScreen(),
      ),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  const _GlassTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF388E3C),
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Zoe'),
          Tab(icon: Icon(Icons.science_outlined), text: 'Glass Box'),
        ],
      ),
    );
  }
}

