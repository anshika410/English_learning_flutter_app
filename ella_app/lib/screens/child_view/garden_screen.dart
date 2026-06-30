// Garden ("My Garden") — API-driven progress map, ported to the Figma design
// (iPhone 16 Plus garden frame): a sky → rolling-meadow backdrop with a level
// badge, sun and clouds, then a vertical run of isometric plots (one per unit
// step). Each plot = turf-shadow ellipse + tile + bush + plants that grow from
// the live GET /users/me/garden data. A fixed "Let's Talk" bar sits at the
// bottom. Tapping a plant opens its Skill Sheet; tapping a plot/label opens the
// Unit Sheet.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme_colors.dart';
import '../../models/garden.dart';
import '../../providers/chat_provider.dart';
import '../../providers/garden_provider.dart';
import 'session_screen.dart';
import 'session_intro.dart';
import 'widgets/garden_dialogs.dart';

// Palette taken from the Figma garden SVG gradients.
const Color _skyTop = Color(0xFFC8DCF0);
const Color _skyBottom = Color(0xFFE4D8E8);
const Color _hillBack = Color(0xFFC4E0BB);
const Color _meadowTop = Color(0xFFA8CCA0);
const Color _meadowBottom = Color(0xFF8EBE82);
const Color _badge = Color(0xFFF09820);

const double _skyHeight = 188;
const double _plotW = 220;
const double _plotH = 190;
const double _tileW = 82;
const double _tileH = _tileW / 105 * 80;
const double _ellipseW = 204;
const double _ellipseH = _ellipseW / 252 * 119;

class GardenScreen extends ConsumerWidget {
  final VoidCallback? onConversationEnded;

  const GardenScreen({super.key, this.onConversationEnded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gardenAsync = ref.watch(gardenProvider);
    return Container(
      color: _meadowBottom,
      child: gardenAsync.when(
        data: (data) => _GardenView(
          data: data,
          onConversationEnded: onConversationEnded,
        ),
        loading: () => const _SkyScaffold(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => _SkyScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your garden',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(gardenProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyScaffold extends StatelessWidget {
  final Widget child;
  const _SkyScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _meadowTop],
        ),
      ),
      child: child,
    );
  }
}

class _GardenView extends ConsumerWidget {
  final GardenData data;
  final VoidCallback? onConversationEnded;
  const _GardenView({
    required this.data,
    required this.onConversationEnded,
  });

  Future<void> _letsTalk(BuildContext context, WidgetRef ref) async {
    // Ensure previous session state is reset before starting new session
    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    
    // If previous chat ended, reset for new session
    if (chatState.hasValue && chatState.requireValue.sessionEnded) {
      await chatNotifier.nextChat();
    }
    if (!context.mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          introText: buildSessionIntroText(topicText: data.recommendedTopic),
          onEnded: onConversationEnded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _SkyHills(level: data.levelLabel, theme: data.theme),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_meadowTop, _meadowBottom],
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.steps.length; i++)
                        _PlotRow(
                          data: data,
                          step: data.steps[i],
                          plotOnLeft: i.isEven,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LetsTalkBar(
              topic: data.recommendedTopic,
              onTalk: () => _letsTalk(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sky + rolling hills ───────────────────────────────────────────────────────

class _SkyHills extends StatelessWidget {
  final String level;
  final String theme;
  const _SkyHills({required this.level, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _skyHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_skyTop, _skyBottom],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 26,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFE08A),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x66FFE08A), blurRadius: 28, spreadRadius: 10),
                ],
              ),
            ),
          ),
          const Positioned(top: 84, left: 28, child: _Cloud(scale: 1.0)),
          const Positioned(top: 56, right: 96, child: _Cloud(scale: 0.7)),
          // Rolling hills filling the bottom of the sky, blending into meadow.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 86,
            child: CustomPaint(painter: _HillsPainter()),
          ),
          // Level / theme badge.
          Positioned(
            top: 16,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _badge,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    level.isEmpty ? 'Your Garden' : level,
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  if (theme.isNotEmpty)
                    Text(
                      theme,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hill (lighter).
    final back = Paint()..color = _hillBack;
    final p1 = Path()
      ..moveTo(0, h * 0.42)
      ..quadraticBezierTo(w * 0.25, h * 0.18, w * 0.5, h * 0.40)
      ..quadraticBezierTo(w * 0.78, h * 0.64, w, h * 0.34)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, back);

    // Front hill (meadow colour — seamless with the meadow container below).
    final front = Paint()..color = _meadowTop;
    final p2 = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.30, h * 0.46, w * 0.58, h * 0.66)
      ..quadraticBezierTo(w * 0.82, h * 0.82, w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(_HillsPainter oldDelegate) => false;
}

class _Cloud extends StatelessWidget {
  final double scale;
  const _Cloud({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 72,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

// ── One plot + its label ──────────────────────────────────────────────────────

class _PlotRow extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  final bool plotOnLeft;
  const _PlotRow(
      {required this.data, required this.step, required this.plotOnLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _plotH,
      child: Stack(
        children: [
          Align(
            alignment:
                plotOnLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: plotOnLeft ? 12 : 0,
                right: plotOnLeft ? 0 : 12,
              ),
              child: _Plot(data: data, step: step),
            ),
          ),
          Positioned(
            top: 16,
            left: plotOnLeft ? null : 18,
            right: plotOnLeft ? 18 : null,
            child: _UnitLabel(
              name: step.name,
              onTap: () => showUnitSheet(context, data, step),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitLabel extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _UnitLabel({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: EllaColors.bubbleSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8D4B8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          name,
          style: GoogleFonts.baloo2(
            fontSize: 13,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4A3621),
          ),
        ),
      ),
    );
  }
}

// ── Plot: turf-shadow ellipse + tile + bush + plants + butterfly ──────────────

class _Plot extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  const _Plot({required this.data, required this.step});

  @override
  Widget build(BuildContext context) {
    final skills = step.skills;
    final tileSpots = _tileSpotsFor(skills.length);
    final hasBloom = step.skills.any((s) => s.stage == PlantStage.bloom);

    return SizedBox(
      width: _plotW,
      height: _plotH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Turf shadow disc.
          Positioned(
            bottom: 6,
            left: (_plotW - _ellipseW) / 2,
            child: SvgPicture.asset('assets/gardent-view/Ellipse.svg',
                width: _ellipseW, height: _ellipseH),
          ),
          // Bush at the base.
          Positioned(
            bottom: 22,
            left: 22,
            child: SvgPicture.asset('assets/gardent-view/bush.svg', width: 38),
          ),
          for (var i = 0; i < skills.length; i++)
            _SkillTile(
              skill: skills[i],
              spot: tileSpots[i],
              onTap: () => showSkillSheet(context, step, skills[i]),
            ),
          for (var i = 0; i < skills.length; i++)
            if (skills[i].stage != PlantStage.bare)
              _SkillPlant(
                skill: skills[i],
                spot: tileSpots[i],
                onTap: () => showSkillSheet(context, step, skills[i]),
              ),
          if (hasBloom)
            const Positioned(
              bottom: 106,
              left: 24,
              child: _Butterfly(),
            ),
        ],
      ),
    );
  }
}

class _TileSpot {
  final double left;
  final double bottom;
  const _TileSpot({required this.left, required this.bottom});
}

List<_TileSpot> _tileSpotsFor(int count) {
  final centerLeft = (_plotW - _tileW) / 2;
  const baseBottom = 34.0;
  if (count <= 0) return const [];

  final templates = <int, List<Offset>>{
    1: const [Offset(0, 0)],
    2: const [Offset(-22, 0), Offset(22, 20)],
    3: const [Offset(-40, 0), Offset(0, 20), Offset(40, 0)],
    4: const [
      Offset(-40, 0),
      Offset(0, 20),
      Offset(0, -20),
      Offset(40, 0),
    ],
    5: const [
      Offset(-40, 0),
      Offset(0, 20),
      Offset(40, 0),
      Offset(-20, -20),
      Offset(20, -20),
    ],
  };

  final offsets = templates[count] ?? _overflowTileOffsets(count);
  return [
    for (final offset in offsets)
      _TileSpot(
        left: centerLeft + offset.dx,
        bottom: baseBottom + offset.dy,
      ),
  ];
}

List<Offset> _overflowTileOffsets(int count) {
  final offsets = <Offset>[];
  const columns = 3;
  const xGap = 45.0;
  const yGap = 24.0;
  for (var i = 0; i < count; i++) {
    final row = i ~/ columns;
    final col = i % columns;
    final rowCount = math.min(columns, count - row * columns);
    final x = (col - (rowCount - 1) / 2) * xGap;
    final y = row.isEven ? -row * yGap : 14 - row * yGap;
    offsets.add(Offset(x, y));
  }
  return offsets;
}

class _SkillTile extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final VoidCallback onTap;
  const _SkillTile({
    required this.skill,
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileAsset = skill.status == SkillStatus.locked
        ? 'assets/gardent-view/tiles.svg'
        : 'assets/gardent-view/tiles-turf.svg';

    return Positioned(
      bottom: spot.bottom,
      left: spot.left,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: SvgPicture.asset(tileAsset, width: _tileW, height: _tileH),
      ),
    );
  }
}

class _SkillPlant extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final VoidCallback onTap;
  const _SkillPlant({
    required this.skill,
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: spot.bottom + _tileH * 0.50,
      left: spot.left + _tileW / 2 - 22,
      child: SizedBox(
        width: 44,
        child: Center(
          child: _Plant(
            skill: skill,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _Plant extends StatelessWidget {
  final GardenSkill skill;
  final VoidCallback onTap;
  const _Plant({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (asset, height) = switch (skill.stage) {
      PlantStage.bloom => (skill.strand.bloomAsset, 76.0),
      PlantStage.growing => ('assets/gardent-view/plants-emerging.svg', 54.0),
      PlantStage.sprout => ('assets/gardent-view/plants-sprout.svg', 34.0),
      PlantStage.bare => ('', 0.0),
    };
    if (asset.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SvgPicture.asset(asset, height: height, fit: BoxFit.contain),
    );
  }
}

class _Butterfly extends StatefulWidget {
  const _Butterfly();
  @override
  State<_Butterfly> createState() => _ButterflyState();
}

class _ButterflyState extends State<_Butterfly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(6 * _ctrl.value, -10 * math.sin(_ctrl.value * math.pi)),
        child: child,
      ),
      child: SvgPicture.asset('assets/gardent-view/butterfly 1.svg',
          width: 26, height: 26),
    );
  }
}

// ── Bottom "Let's Talk" bar ────────────────────────────────────────────────────

class _LetsTalkBar extends StatelessWidget {
  final String topic;
  final VoidCallback onTalk;
  const _LetsTalkBar({required this.topic, required this.onTalk});

  @override
  Widget build(BuildContext context) {
    final line = topic.isEmpty
        ? 'Ready when you are. Shall we?'
        : 'Today, I wanted to talk about $topic. Shall we?';
    return Container(
      decoration: BoxDecoration(
        color: EllaColors.bubbleSurface,
        border:
            const Border(top: BorderSide(color: EllaColors.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: EllaColors.zoeMintLight,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/mascot-animations/juggling.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: EllaColors.bubbleText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onTalk,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [EllaColors.mangoTop, EllaColors.mangoMain],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: EllaColors.mangoDark,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    "Let's Talk",
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A2200),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
