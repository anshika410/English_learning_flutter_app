import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../services/tts_manager.dart';
import '../theme/ella_theme.dart';
import '../theme/ella_responsive.dart';
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
  static const String _openingLine =
      'What should we talk about today? Choose from any of the topics or just talk to me about anything if you are not sure.';

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
  final TtsManager _tts = TtsManager();
  bool _isPlayingOpeningLine = false;

  _MascotStep get _currentMascotStep => _mascotSequence[_sequenceIndex];

  @override
  void initState() {
    super.initState();
    // Ensure ChatProvider services are initialized (loads persisted user data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().ensureInitialized();
    });
    _playOpeningLine();
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
      const AssetImage('assets/mascot-animations/speaking.webp'),
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
    _tts.dispose();
    super.dispose();
  }

  Future<void> _playOpeningLine() async {
    if (!mounted) return;
    setState(() => _isPlayingOpeningLine = true);
    try {
      await _tts.initialize();
      await _tts.speak(_openingLine);
    } catch (_) {
      // Keep home UX resilient if TTS is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _isPlayingOpeningLine = false;
          _sequenceIndex = 0;
        });
        _scheduleNextMascotStep();
      }
    }
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

  PageRoute<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );

  void _startConversation(BuildContext context, {String? topic}) {
    Navigator.of(context).push(_fadeRoute(ConversationScreen(topic: topic ?? 'Free Talk')));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = EllaResponsive.isWide(context);

    // ── Profile button (pill on wide, circle on mobile) ────────────────
    final profileButton = GestureDetector(
      onTap: () => Navigator.of(context).push(_fadeRoute(const ProfileScreen())),
      child: isWide
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: EllaColors.neutralBg,
                border: Border.all(color: EllaColors.neutralBorder, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: EllaColors.neutralBorder,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: EllaColors.neutralSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Profile',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.neutralSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EllaColors.neutralBg,
                border: Border.all(color: EllaColors.neutralBorder, width: 2),
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
    );

    // ── Mascot ─────────────────────────────────────────────────────────
    final mascot = Container(
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
            _isPlayingOpeningLine
                ? 'assets/mascot-animations/speaking.webp'
                : _currentMascotStep.assetPath,
            key: ValueKey<String>(
              _isPlayingOpeningLine
                  ? 'home-opening-speaking'
                  : 'home-loop-$_sequenceIndex',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );

    // ── Topic pills ────────────────────────────────────────────────────
    final topicPills = Padding(
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
    );

    // ── Bottom row ─────────────────────────────────────────────────────
    final textBlock = Column(
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
    );

    final bottomRow = isWide
        ? Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                textBlock,
                const SizedBox(width: 24),
                EllaPrimaryButton(
                  label: 'Talk to Zoe',
                  onTap: () => _startConversation(context),
                ),
              ],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: textBlock),
              const SizedBox(width: 16),
              SizedBox(
                width: 140,
                child: EllaPrimaryButton(
                  label: 'Talk to Zoe',
                  onTap: () => _startConversation(context),
                ),
              ),
            ],
          );

    // ── Central content block (mascot + headline + pills) ──────────────
    final centralContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mascot,
        const SizedBox(height: 24),
        Text(
          isWide
              ? 'What Should We Talk About Today?'
              : 'What Should We Talk\nAbout Today?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Chillax',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 24),
        topicPills,
      ],
    );

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'zoe.',
                    style: TextStyle(
                      fontFamily: 'Chillax',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.mangoMain,
                    ),
                  ),
                  const Spacer(),
                  profileButton,
                ],
              ),
            ),

            // ── Central block: vertically centred on wide, top on mobile ──
            if (isWide)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [centralContent],
                ),
              )
            else ...[
              const SizedBox(height: 32),
              centralContent,
              const Spacer(),
            ],

            // ── Bottom row ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: bottomRow,
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
