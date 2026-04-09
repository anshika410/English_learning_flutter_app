import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'conversation_screen.dart';

const List<String> _topics = [
  'Sports',
  'Food',
  'About Myself',
  'Daily Life',
  'Travel',
  'Movies & TV',
  'Work & Study',
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            // ── Top bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EllaColors.skyLightest,
                      border: Border.all(color: EllaColors.ink, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: EllaColors.skyDark,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Ella avatar (no circle/background) ────────────────────
            SizedBox(
              width: 200,
              height: 200,
              child: Image.asset(
                'images/ella-neutral.png',
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 24),

            // ── Heading ───────────────────────────────────────────────
            Text(
              'Ready to talk today? 👋',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Chillax',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Topic chips ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: _topics
                    .map(
                      (t) => _TopicChip(
                        label: t,
                        onTap: () => _startConversation(context, topic: t),
                      ),
                    )
                    .toList(),
              ),
            ),

            const Spacer(),

            // ── Bottom bar ────────────────────────────────────────────
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
                            'Want to talk about something?',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: EllaColors.neutralSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Let Zoe decide the topic',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
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

// ─── Topic Chip ───────────────────────────────────────────────────────────────

class _TopicChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopicChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: EllaColors.neutralSurface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: EllaColors.neutralBorder, width: 2),
          boxShadow: const [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: Offset(0, 3),
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
