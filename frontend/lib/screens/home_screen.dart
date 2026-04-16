import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'conversation_screen.dart';
import 'profile_screen.dart';

const List<String> _topics = [
  'Sports',
  'Food',
  'About Myself',
  'Daily Life',
  'Travel',
  'Movies & TV',
  'Work & Study',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<_MascotStep> _mascotSequence = [
    _MascotStep(
      assetPath: 'assets/mascot-animations/listening.webp',
      holdDuration: Duration(milliseconds: 8000),
    ),
    _MascotStep(
      assetPath: 'assets/mascot-animations/juggling.webp',
      holdDuration: Duration(milliseconds: 4000),
    ),
    _MascotStep(
      assetPath: 'assets/mascot-animations/listening.webp',
      holdDuration: Duration(milliseconds: 8000),
    ),
    _MascotStep(
      assetPath: 'assets/mascot-animations/bubblepop.webp',
      holdDuration: Duration(milliseconds: 4000),
    ),
  ];

  static final List<_TopicChipPalette> _topicPalettes = [
    const _TopicChipPalette(
      background: EllaColors.mangoLightest,
      borderAndShadow: EllaColors.mangoDark,
    ),
    const _TopicChipPalette(
      background: EllaColors.roseLightest,
      borderAndShadow: EllaColors.roseDark,
    ),
    const _TopicChipPalette(
      background: EllaColors.skyLightest,
      borderAndShadow: EllaColors.skyDark,
    ),
    const _TopicChipPalette(
      background: Color(0xFFFFF7CC),
      borderAndShadow: Color(0xFFB89500),
    ),
    const _TopicChipPalette(
      background: EllaColors.limeLightest,
      borderAndShadow: EllaColors.limeDark,
    ),
  ];

  int _sequenceIndex = 0;
  Timer? _mascotTimer;
  bool _didPrecacheMascotImages = false;

  _MascotStep get _currentMascotStep => _mascotSequence[_sequenceIndex];

  @override
  void initState() {
    super.initState();
    _scheduleNextMascotStep();
    // Ensure ChatProvider services are initialized (loads persisted user data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().ensureInitialized();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheMascotImages) return;

    precacheImage(
      const AssetImage('assets/mascot-animations/listening.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/juggling.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/bubblepop.webp'),
      context,
    );
    _didPrecacheMascotImages = true;
  }

  @override
  void dispose() {
    _mascotTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextMascotStep() {
    _mascotTimer?.cancel();
    _mascotTimer = Timer(_currentMascotStep.holdDuration, () {
      if (!mounted) return;
      setState(() {
        _sequenceIndex = (_sequenceIndex + 1) % _mascotSequence.length;
      });
      _scheduleNextMascotStep();
    });
  }

  void _startConversation(BuildContext context, {String? topic}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(topic: topic ?? 'Free Talk'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    'zoe.',
                    style: const TextStyle(
                      fontFamily: 'Chillax',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.mangoMain,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EllaColors.neutralBg,
                        border: Border.all(
                          color: EllaColors.neutralBorder,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: EllaColors.neutralBorder,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: EllaColors.neutralSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EllaColors.zoeMintLight,
                boxShadow: [
                  BoxShadow(
                    color: EllaColors.neutralMuted.withValues(alpha: 0.40),
                    offset: const Offset(0, 6),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: ClipOval(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Image.asset(
                    _currentMascotStep.assetPath,
                    key: ValueKey<int>(_sequenceIndex),
                    fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'What should we talk\nabout today?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Chillax',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(_topics.length, (index) {
                  final topic = _topics[index];
                  final palette = _topicPalettes[index % _topicPalettes.length];
                  return _TopicChip(
                    label: topic,
                    palette: palette,
                    onTap: () => _startConversation(context, topic: topic),
                  );
                }),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Not sure what to talk about?',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: EllaColors.neutralSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Zoe can pick something fun',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: EllaColors.neutralPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 140,
                      child: EllaPrimaryButton(
                        label: 'Talk to Zoe',
                        onTap: () => _startConversation(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final _TopicChipPalette palette;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: palette.borderAndShadow, width: 2),
          boxShadow: [
            BoxShadow(
              color: palette.borderAndShadow,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
        ),
      ),
    );
  }
}

class _MascotStep {
  final String assetPath;
  final Duration holdDuration;

  const _MascotStep({required this.assetPath, required this.holdDuration});
}

class _TopicChipPalette {
  final Color background;
  final Color borderAndShadow;

  const _TopicChipPalette({
    required this.background,
    required this.borderAndShadow,
  });
}
