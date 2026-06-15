// Non-linear garden map — full-screen port of #garden from ella-garden-nonlinear.html.
// Five themed "beds" (one per engine UnitStep) sit on a clustered, gate-free map
// connected by a dashed trail "web". Each bed shows its skills as isometric SVG
// tiles whose state is derived live from MemoryState via engine.gardenStateOf.
// Tapping a tile opens a detail sheet with its can-do statement and state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/engine.dart';
import '../../core/skill_data.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import 'garden_art.dart';

// ── Layout constants (from the HTML THEMES / links / TPOS arrays) ─────────────

class _BedDef {
  final String step; // UnitStep.step '1'..'5'
  final double leftPct; // bed centre, % of field width
  final double topPx; // bed centre, px down the 1000px field
  const _BedDef(this.step, this.leftPct, this.topPx);
}

const List<_BedDef> _beds = [
  _BedDef('1', 30, 140),
  _BedDef('2', 70, 240),
  _BedDef('3', 32, 450),
  _BedDef('4', 71, 620),
  _BedDef('5', 40, 820),
];

// Trail network (a web, not a route) between bed steps.
const List<List<String>> _links = [
  ['1', '2'], ['1', '3'], ['2', '3'], ['3', '4'], ['3', '5'], ['4', '5'],
];

// Tile cluster offsets within the 168-wide bed viz.
const List<Offset> _tilePos = [
  Offset(68, 2), Offset(96, 18), Offset(40, 18), Offset(68, 34),
];

const double _fieldHeight = 1000;
const double _bedW = 168;
const double _bedH = 132;

UnitStep _stepByNum(String n) => kUnitSteps.firstWhere((u) => u.step == n);

// ── Screen ───────────────────────────────────────────────────────────────────

class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _GardenMap(state: s),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Garden error: $e')),
    );
  }
}

class _GardenMap extends StatelessWidget {
  final ChatState state;
  const _GardenMap({required this.state});

  @override
  Widget build(BuildContext context) {
    final mem = state.memory;
    final tally = gardenTally(mem);
    final changedIds = state.lastChanges.map((c) => c.id).toSet();

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1),
          radius: 1.1,
          colors: [Color(0xFFF4FBE9), Color(0xFFEAF6DA), Color(0xFFE2F0CE)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Column(
        children: [
          _Header(tally: tally),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return SingleChildScrollView(
                  child: SizedBox(
                    width: w,
                    height: _fieldHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Trail web behind everything.
                        Positioned.fill(
                          child: CustomPaint(painter: _WebPainter(width: w)),
                        ),
                        for (final b in _beds)
                          _BedWidget(
                            def: b,
                            mem: mem,
                            fieldWidth: w,
                            changedIds: changedIds,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header + meter ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final GardenTally tally;
  const _Header({required this.tally});

  @override
  Widget build(BuildContext context) {
    final pct = tally.total == 0 ? 0.0 : tally.owned / tally.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(
        children: [
          const Text(
            'Your garden',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: EllaColors.limeDeepest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🌸 ${tally.owned} of ${tally.total} skills in bloom  ·  ${tally.sprouting} sprouting',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: EllaColors.limeDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFFD6E8BE),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [EllaColors.limeMain, EllaColors.mangoMain],
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trail web painter ────────────────────────────────────────────────────────

class _WebPainter extends CustomPainter {
  final double width;
  const _WebPainter({required this.width});

  Offset _center(String step) {
    final b = _beds.firstWhere((d) => d.step == step);
    return Offset(b.leftPct / 100 * width, b.topPx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = const Color(0xFFBBD79A).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    for (final link in _links) {
      final p1 = _center(link[0]);
      final p2 = _center(link[1]);
      final mx = (p1.dx + p2.dx) / 2 + (p2.dy > p1.dy ? 18 : -18);
      final my = (p1.dy + p2.dy) / 2;
      final ctrl = Offset(mx, my);

      // Walk the quadratic bezier and drop dots (matches dasharray "1 13").
      const steps = 60;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final mt = 1 - t;
        final pt = Offset(
          mt * mt * p1.dx + 2 * mt * t * ctrl.dx + t * t * p2.dx,
          mt * mt * p1.dy + 2 * mt * t * ctrl.dy + t * t * p2.dy,
        );
        if (i % 3 == 0) canvas.drawCircle(pt, 1.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_WebPainter old) => old.width != width;
}

// ── A single bed ─────────────────────────────────────────────────────────────

class _BedWidget extends StatelessWidget {
  final _BedDef def;
  final MemoryState mem;
  final double fieldWidth;
  final Set<String> changedIds;

  const _BedWidget({
    required this.def,
    required this.mem,
    required this.fieldWidth,
    required this.changedIds,
  });

  @override
  Widget build(BuildContext context) {
    final step = _stepByNum(def.step);
    final states = step.skills.map((s) => gardenStateOf(mem, s.id)).toList();
    final owned = states.where((s) => s == 3).length;
    final active = states.any((s) => s == 1 || s == 2);
    final dormant = !active && owned == 0;

    final centerX = def.leftPct / 100 * fieldWidth;
    final left = centerX - _bedW / 2;
    final top = def.topPx - _bedH / 2;

    return Positioned(
      left: left,
      top: top,
      width: _bedW,
      child: Column(
        children: [
          SizedBox(
            width: _bedW,
            height: _bedH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (active)
                  const Positioned(
                    left: 9,
                    top: 18,
                    child: _Glow(),
                  ),
                // Mound
                Positioned(
                  left: 0,
                  bottom: 8,
                  child: SvgPicture.string(_moundSvg, width: _bedW, height: 50),
                ),
                // Building
                Positioned(
                  left: _bedW / 2 - 36,
                  bottom: 16,
                  child: SvgPicture.string(buildingSvg(states), width: 72, height: 72),
                ),
                // Tiles
                for (var j = 0; j < step.skills.length; j++)
                  Positioned(
                    left: _tilePos[j].dx,
                    top: _tilePos[j].dy,
                    child: _Tile(
                      state: states[j],
                      grew: changedIds.contains(step.skills[j].id),
                      onTap: () => _openSheet(context, step, j, states[j]),
                    ),
                  ),
                if (active)
                  const Positioned(right: 6, top: 4, child: _Butterfly()),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            step.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: dormant
                  ? EllaColors.muted
                  : (owned == states.length ? EllaColors.limeDeepest : EllaColors.secondary),
            ),
          ),
          Text(
            '$owned/${states.length} bloomed',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: EllaColors.muted,
            ),
          ),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: EllaColors.mangoMain,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'GROWING NOW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const String _moundSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="168" height="50" viewBox="0 0 168 50">'
    '<ellipse cx="84" cy="30" rx="80" ry="20" fill="#CFE9A8"/>'
    '<ellipse cx="84" cy="26" rx="80" ry="20" fill="#DFF2BE" stroke="#AFD380" stroke-width="2"/></svg>';

// ── Tile (with grow pop) ─────────────────────────────────────────────────────

class _Tile extends StatefulWidget {
  final int state;
  final bool grew;
  final VoidCallback onTap;
  const _Tile({required this.state, required this.grew, required this.onTap});

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 680));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    if (widget.grew) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: SvgPicture.string(tileSvg(widget.state), width: 40, height: 61),
      ),
    );
  }
}

// ── Glow pulse + butterfly ───────────────────────────────────────────────────

class _Glow extends StatefulWidget {
  const _Glow();
  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 0.85).animate(_ctrl),
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.12).animate(_ctrl),
        child: Container(
          width: 150,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x66FFAA20), Color(0x00FFAA20)],
            ),
          ),
        ),
      ),
    );
  }
}

class _Butterfly extends StatefulWidget {
  const _Butterfly();
  @override
  State<_Butterfly> createState() => _ButterflyState();
}

class _ButterflyState extends State<_Butterfly> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value * 2 * 3.14159;
        return Transform.translate(
          offset: Offset(8 * (1 - (t / 6)).abs(), -8 * (0.5 + 0.5 * _sin(t))),
          child: child,
        );
      },
      child: const Text('🦋', style: TextStyle(fontSize: 15)),
    );
  }

  double _sin(double x) {
    // light-weight sine without importing dart:math at widget scope
    x %= 2 * 3.14159;
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }
}

// ── Detail sheet ─────────────────────────────────────────────────────────────

void _openSheet(BuildContext context, UnitStep step, int index, int state) {
  final skill = step.skills[index];
  final (label, pillBg, pillFg) = switch (state) {
    3 => ('Owned', EllaColors.limeLightest, EllaColors.limeDark),
    2 => ('Growing', EllaColors.skyLightest, EllaColors.skyDark),
    1 => ('Emerging', EllaColors.mangoLightest, EllaColors.mangoDark),
    _ => ('Not seen yet', const Color(0xFFF0ECE2), EllaColors.muted),
  };
  final evidence = switch (state) {
    3 => 'Owned — used confidently across more than one topic and day.',
    2 => "Growing — you've used it on your own. One more spread to lock it in.",
    1 => 'Emerging — spotted once. Zoe will weave in more chances to use it.',
    _ => "No evidence yet — it'll sprout the moment you use it, whatever theme you're on.",
  };

  showModalBottomSheet(
    context: context,
    backgroundColor: EllaColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EllaColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: pillFg,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: EllaColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            skill.text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: EllaColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            evidence,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: EllaColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: EllaColors.surface,
                foregroundColor: EllaColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(18),
                  ),
                ),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}
