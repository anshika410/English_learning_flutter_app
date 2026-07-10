// Zoe mascot — a native, layered vector animation (no image/WebP switching).
//
// The geometry is the same sprout art shipped as assets/homescreen/new/mascot-*.svg
// (viewBox 563 x 667); here every layer (body, eyes, cheeks, mouth, leaves,
// stems, thinking droplets) is a Path drawn by a CustomPainter so each part can
// move independently. Timings/poses follow docs/mascot-animation-states/
// motion-spec.json.
//
// Modes: listening (calm breath + synced leaf sway + occasional blink),
// speaking (breath + opposing leaf sway + weighted pseudo-viseme mouth loop),
// thinking (breath + curious eyes + asymmetric leaf sway + idea droplets), idle
// (ambient; treated as listening). reducedMotion freezes everything to a calm,
// closed-mouth pose with no droplets.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

enum ZoeMascotMode {
  speaking,
  listening,
  thinking,
  idle,
  sleep,
}

class ZoeMascot extends StatefulWidget {
  final ZoeMascotMode mode;
  final double size;
  final bool reducedMotion;
  final bool clipToCircle;

  const ZoeMascot({
    super.key,
    required this.mode,
    this.size = 200,
    this.reducedMotion = false,
    this.clipToCircle = false,
  });

  @override
  State<ZoeMascot> createState() => _ZoeMascotState();
}

class _ZoeMascotState extends State<ZoeMascot>
    with SingleTickerProviderStateMixin {
  // A free-running clock (elapsed ms) drives every loop from its own period, so
  // the sub-animations stay independent and never resync the way a single
  // 0→1 controller would. The painter repaints off this notifier.
  late final Ticker _ticker;
  final ValueNotifier<double> _clockMs = ValueNotifier<double>(0);

  final math.Random _rng = math.Random();
  Timer? _visemeTimer;
  String _viseme = 'rest';
  int _stepsUntilRest = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clockMs.value = elapsed.inMicroseconds / 1000.0;
    });
    _applyMotion();
  }

  @override
  void didUpdateWidget(covariant ZoeMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _applyMotion();
    }
  }

  void _applyMotion() {
    _visemeTimer?.cancel();
    _viseme = 'rest';
    if (widget.reducedMotion) {
      if (_ticker.isActive) _ticker.stop();
      _clockMs.value = 0;
      return;
    }
    if (!_ticker.isActive) _ticker.start();
    if (widget.mode == ZoeMascotMode.speaking) {
      _stepsUntilRest = _randInt(5, 9);
      _scheduleViseme(0);
    }
  }

  // ── Pseudo-viseme scheduler (speaking only) ────────────────────────────────
  // Weighted random poses, avoiding back-to-back heavy shapes and inserting a
  // short rest every 5–9 steps so the loop reads like phrasing (mirrors the
  // reference preview's scheduler).
  static const Map<String, ({double min, double max, double weight})>
  _visemeSpecs = {
    'rest': (min: 180, max: 260, weight: 0.05),
    'press': (min: 88, max: 132, weight: 0.12),
    'tight': (min: 96, max: 150, weight: 0.12),
    'narrow': (min: 112, max: 170, weight: 0.18),
    'mid': (min: 142, max: 224, weight: 0.22),
    'open': (min: 156, max: 238, weight: 0.15),
    'wide': (min: 174, max: 270, weight: 0.08),
    'round': (min: 168, max: 260, weight: 0.08),
  };

  void _scheduleViseme(double delayMs) {
    _visemeTimer?.cancel();
    _visemeTimer = Timer(Duration(milliseconds: delayMs.round()), () {
      if (!mounted) return;
      final String next;
      final double duration;
      if (_stepsUntilRest <= 0) {
        next = 'rest';
        duration = _visemeDuration('rest') + _randInt(140, 260).toDouble();
        _stepsUntilRest = _randInt(5, 9);
      } else {
        next = _nextViseme();
        duration = _visemeDuration(next);
        _stepsUntilRest--;
      }
      setState(() => _viseme = next);
      _scheduleViseme(duration);
    });
  }

  String _nextViseme() {
    var candidates = _visemeSpecs.keys.toList();
    if (_viseme == 'wide' || _viseme == 'round' || _viseme == 'open') {
      candidates = candidates
          .where((n) => n != 'wide' && n != 'round' && n != 'open')
          .toList();
    }
    if (_viseme == 'press' || _viseme == 'tight') {
      candidates = candidates
          .where((n) => n != 'press' && n != 'tight')
          .toList();
    }
    if (_viseme == 'rest') {
      candidates = candidates.where((n) => n != 'rest').toList();
    }
    return _weightedChoice(candidates);
  }

  String _weightedChoice(List<String> candidates) {
    final weights = candidates.map((n) {
      final drift = (_rng.nextDouble() * 2 - 1) * 0.18;
      return math.max(0.01, _visemeSpecs[n]!.weight * (1 + drift));
    }).toList();
    final total = weights.reduce((a, b) => a + b);
    var needle = _rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      needle -= weights[i];
      if (needle <= 0) return candidates[i];
    }
    return candidates.last;
  }

  double _visemeDuration(String viseme) {
    final spec = _visemeSpecs[viseme]!;
    final mid = (spec.min + spec.max) / 2;
    final spread = (spec.max - spec.min) / 2;
    return math.max(70, mid + (_rng.nextDouble() * 2 - 1) * spread);
  }

  int _randInt(int min, int max) => min + _rng.nextInt(max - min + 1);

  @override
  void dispose() {
    _visemeTimer?.cancel();
    _ticker.dispose();
    _clockMs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lower bound only guards against degenerate sizes — compact placements
    // (e.g. the 44px mascot beside the garden "Let's Talk" pill) must render
    // at their requested size, not get bumped up.
    final artSize = widget.size.clamp(32.0, 320.0);

    final content = SizedBox(
      width: artSize,
      height: artSize,
      child: CustomPaint(
        size: Size(artSize, artSize),
        painter: _ZoeMascotPainter(
          clock: _clockMs,
          mode: widget.mode,
          viseme: _viseme,
          reducedMotion: widget.reducedMotion,
        ),
      ),
    );

    return widget.clipToCircle ? ClipOval(child: content) : content;
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _ZoeMascotPainter extends CustomPainter {
  final ValueNotifier<double> clock;
  final ZoeMascotMode mode;
  final String viseme;
  final bool reducedMotion;

  _ZoeMascotPainter({
    required this.clock,
    required this.mode,
    required this.viseme,
    required this.reducedMotion,
  }) : super(repaint: clock);

  static const double _vbW = 563;
  static const double _vbH = 667;

  // Pivots (viewBox space).
  static const Offset _corePivot = Offset(281.5, 430); // breathe, ~50%/66%
  static const Offset _eyesCenter = Offset(260.5, 423.5);
  static const Offset _eyeLeftCenter = Offset(168, 423.497);
  static const Offset _eyeRightCenter = Offset(353, 423.497);
  static const Offset _leafLeftPivot = Offset(242.3, 93.7); // base of left leaf
  static const Offset _leafRightPivot = Offset(284.2, 93.7);
  static const Offset _mouthPivot = Offset(261, 507);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _vbW, size.height / _vbH);
    final dx = (size.width - _vbW * scale) / 2;
    final dy = (size.height - _vbH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final t = reducedMotion ? 0.0 : clock.value;

    // Whole-mascot breathe wraps every other layer.
    final body = _bodyBreathe(t);
    canvas.save();
    _applyTransform(
      canvas,
      _corePivot,
      tx: body.tx,
      ty: body.ty,
      rot: body.rot,
      sx: body.scale,
      sy: body.scale,
    );

    _drawBody(canvas);
    _drawEyes(canvas, t);
    _drawCheeks(canvas);
    _drawMouth(canvas);
    _drawLeaves(canvas, t);
    _drawStems(canvas);
    if ((mode == ZoeMascotMode.thinking || mode == ZoeMascotMode.sleep) && !reducedMotion) {
      _drawDroplets(canvas, t);
    }

    canvas.restore();
    canvas.restore();
  }

  // ── Layers ─────────────────────────────────────────────────────────────────

  void _drawBody(Canvas canvas) {
    canvas.drawPath(_paths.body, _fill(0xFF98F8E9));
    canvas.drawPath(_paths.body, _stroke(0xFF4B978F, 14));
  }

  void _drawEyes(Canvas canvas, double t) {
    final eyePaint = _fill(0xFF070E0B);
    if (mode == ZoeMascotMode.thinking && !reducedMotion) {
      // Curious squint — each eye tilts inward and shortens; no blink.
      _applyTransformScoped(
        canvas,
        _eyeLeftCenter,
        ty: 5,
        rot: _rad(-5),
        sy: 0.66,
        draw: () => canvas.drawPath(_paths.eyeLeft, eyePaint),
      );
      _applyTransformScoped(
        canvas,
        _eyeRightCenter,
        ty: 3,
        rot: _rad(5),
        sy: 0.66,
        draw: () => canvas.drawPath(_paths.eyeRight, eyePaint),
      );
      return;
    }
    if (mode == ZoeMascotMode.sleep) {
      // Eyes closed for sleeping.
      _applyTransformScoped(
        canvas,
        _eyeLeftCenter,
        ty: 3,
        sy: 0.15,
        draw: () => canvas.drawPath(_paths.eyeLeft, eyePaint),
      );
      _applyTransformScoped(
        canvas,
        _eyeRightCenter,
        ty: 3,
        sy: 0.15,
        draw: () => canvas.drawPath(_paths.eyeRight, eyePaint),
      );
      return;
    }
    final blink = reducedMotion ? 1.0 : _blinkScaleY(t);
    _applyTransformScoped(
      canvas,
      _eyesCenter,
      sy: blink,
      draw: () {
        canvas.drawPath(_paths.eyeLeft, eyePaint);
        canvas.drawPath(_paths.eyeRight, eyePaint);
      },
    );
  }

  void _drawCheeks(Canvas canvas) {
    canvas.drawPath(_paths.cheekLeft, _fill(0xFFB4DCDA));
    canvas.drawPath(_paths.cheekRight, _fill(0xFFB6DCDB));
  }

  void _drawMouth(Canvas canvas) {
    final pose = _mouthPose();
    _applyTransformScoped(
      canvas,
      _mouthPivot,
      tx: pose.tx,
      ty: pose.ty,
      rot: pose.rot,
      sx: pose.sx,
      sy: pose.sy,
      draw: () {
        if (pose.open) {
          canvas.drawPath(_paths.mouthDark, _fill(0xFF890B0D));
          canvas.drawPath(_paths.mouthRed, _fill(0xFFFF4D3F));
        } else {
          canvas.drawPath(_paths.mouthClosed, _stroke(0xFF070E0B, 8, round: true));
        }
      },
    );
  }

  void _drawLeaves(Canvas canvas, double t) {
    final (left, right) = _leafSway(t);
    final leafFill = _fill(0xFF72A562);
    final leafStroke = _stroke(0xFF3D8449, 7);
    _applyTransformScoped(
      canvas,
      _leafRightPivot,
      rot: right,
      draw: () {
        canvas.drawPath(_paths.leafRight, leafFill);
        canvas.drawPath(_paths.leafRight, leafStroke);
      },
    );
    _applyTransformScoped(
      canvas,
      _leafLeftPivot,
      rot: left,
      draw: () {
        canvas.drawPath(_paths.leafLeft, leafFill);
        canvas.drawPath(_paths.leafLeft, leafStroke);
      },
    );
  }

  void _drawStems(Canvas canvas) {
    canvas.drawPath(_paths.stemRight, _stroke(0xFF3D8449, 6, round: true));
    canvas.drawPath(_paths.stemLeft, _stroke(0xFF3D8449, 7, round: true));
  }

  void _drawDroplets(Canvas canvas, double t) {
    final fill = _fill(0xFF9CDCE8);
    final stroke = _stroke(0xFF4C8290, 5);
    const delays = [0.0, 280.0, 560.0];
    final drops = [_paths.droplet1, _paths.droplet2, _paths.droplet3];
    final pivots = [
      const Offset(226, -5.1),
      const Offset(280, -29.1),
      const Offset(334, -5.1),
    ];
    for (var i = 0; i < drops.length; i++) {
      final phase = (((t - delays[i]) % 2700) + 2700) % 2700 / 2700;
      final opacity = _dropletOpacity(phase);
      if (opacity <= 0.001) continue;
      final ty = _dropletTranslateY(phase);
      final s = _dropletScale(phase);
      _applyTransformScoped(
        canvas,
        pivots[i],
        ty: ty,
        sx: s,
        sy: s,
        draw: () {
          canvas.drawPath(drops[i], _alpha(fill, opacity));
          canvas.drawPath(drops[i], _alpha(stroke, opacity));
        },
      );
    }
  }

  // ── Motion curves (values from motion-spec.json / source-preview.html) ──────

  ({double tx, double ty, double rot, double scale}) _bodyBreathe(double t) {
    if (reducedMotion) return (tx: 0, ty: 0, rot: 0, scale: 1);
    if (mode == ZoeMascotMode.speaking) {
      final p = (t % 2600) / 2600;
      const ats = [0.0, 0.42, 0.72, 1.0];
      return (
        tx: 0.0,
        ty: _kf(p, ats, const [0, -4, -1, 0]),
        rot: _rad(_kf(p, ats, const [0, 0.7, -0.4, 0])),
        scale: _kf(p, ats, const [1, 1.008, 1.003, 1]),
      );
    }
    // listening / thinking / idle share the calm 3200ms breath.
    final p = (t % 3200) / 3200;
    const ats = [0.0, 0.5, 1.0];
    return (
      tx: 0.0,
      ty: _kf(p, ats, const [0, -5, 0]),
      rot: _rad(_kf(p, ats, const [0, -1.2, 0])),
      scale: _kf(p, ats, const [1, 1.012, 1]),
    );
  }

  (double left, double right) _leafSway(double t) {
    if (reducedMotion) return (0, 0);
    switch (mode) {
      case ZoeMascotMode.speaking:
        final p = (t % 2600) / 2600;
        const ats = [0.0, 0.42, 0.72, 1.0];
        return (
          _rad(_kf(p, ats, const [0, -2.2, 0.8, 0])),
          _rad(_kf(p, ats, const [0, 2.2, -0.8, 0])),
        );
      case ZoeMascotMode.thinking:
        final p = (t % 4200) / 4200;
        const ats = [0.0, 0.38, 0.66, 1.0];
        return (
          _rad(_kf(p, ats, const [0, -3.4, 1.2, 0])),
          _rad(_kf(p, ats, const [0, 3.4, -1.2, 0])),
        );
      case ZoeMascotMode.sleep:
      case ZoeMascotMode.listening:
      case ZoeMascotMode.idle:
        final p = (t % 3600) / 3600;
        const ats = [0.0, 0.45, 0.7, 1.0];
        final v = _rad(_kf(p, ats, const [0, 2.2, -1, 0]));
        return (v, v);
    }
  }

  double _blinkScaleY(double t) {
    if (mode == ZoeMascotMode.speaking) {
      final p = (t % 4300) / 4300;
      return _kf(p, const [0, 0.86, 0.88, 0.91, 1.0],
          const [1, 1, 0.12, 1, 1]);
    }
    // calm blink (listening / idle)
    final p = (t % 5200) / 5200;
    return _kf(p, const [0, 0.89, 0.91, 0.94, 1.0], const [1, 1, 0.12, 1, 1]);
  }

  // Which mouth art + transform for the current pose.
  ({bool open, double tx, double ty, double rot, double sx, double sy})
  _mouthPose() {
    if (reducedMotion) {
      return (open: false, tx: 0, ty: 0, rot: 0, sx: 1, sy: 1);
    }
    if (mode == ZoeMascotMode.thinking) {
      // Small, closed, off-centre thinking mouth.
      return (open: false, tx: 8, ty: -3, rot: _rad(-2), sx: 0.58, sy: 0.82);
    }
    if (mode == ZoeMascotMode.sleep) {
      // Small open mouth for snoring.
      return (open: true, tx: 0, ty: -1, rot: 0, sx: 0.6, sy: 0.6);
    }
    if (mode != ZoeMascotMode.speaking) {
      return (open: false, tx: 0, ty: 0, rot: 0, sx: 1, sy: 1);
    }
    return switch (viseme) {
      'press' => (open: false, tx: 0, ty: -2, rot: 0, sx: 0.72, sy: 0.78),
      'tight' => (open: false, tx: 0, ty: -1, rot: 0, sx: 0.9, sy: 0.52),
      'narrow' => (open: true, tx: 0, ty: -3, rot: 0, sx: 0.54, sy: 0.34),
      'mid' => (open: true, tx: 0, ty: -1, rot: 0, sx: 0.78, sy: 0.56),
      'open' => (open: true, tx: 0, ty: -1, rot: 0, sx: 0.9, sy: 0.78),
      'wide' => (open: true, tx: 0, ty: 0, rot: 0, sx: 1.02, sy: 0.96),
      'round' => (open: true, tx: 0, ty: -1, rot: 0, sx: 0.62, sy: 0.82),
      _ => (open: false, tx: 0, ty: 0, rot: 0, sx: 1, sy: 1), // rest
    };
  }

  double _dropletOpacity(double p) => _kf(
        p,
        const [0, 0.18, 0.30, 0.58, 0.72, 1.0],
        const [0, 0, 1, 1, 0, 0],
      );

  double _dropletTranslateY(double p) => _kf(
        p,
        const [0, 0.18, 0.30, 0.58, 0.72, 1.0],
        const [10, 10, 0, 0, -10, 10],
      );

  double _dropletScale(double p) => _kf(
        p,
        const [0, 0.18, 0.30, 0.58, 0.72, 1.0],
        const [0.62, 0.62, 1, 1, 0.86, 0.62],
      );

  // ── Helpers ──────────────────────────────────────────────────────────────

  static double _rad(double deg) => deg * math.pi / 180;

  // Piecewise keyframe interpolation with an ease-in-out on each segment.
  static double _kf(double phase, List<double> ats, List<double> vals) {
    if (phase <= ats.first) return vals.first;
    for (var i = 0; i < ats.length - 1; i++) {
      if (phase >= ats[i] && phase <= ats[i + 1]) {
        final span = ats[i + 1] - ats[i];
        final localT = span <= 0 ? 0.0 : (phase - ats[i]) / span;
        return vals[i] + (vals[i + 1] - vals[i]) * _easeInOut(localT);
      }
    }
    return vals.last;
  }

  static double _easeInOut(double t) {
    if (t < 0.5) return 2 * t * t;
    final p = -2 * t + 2;
    return 1 - p * p / 2;
  }

  static Paint _fill(int color) => Paint()
    ..style = PaintingStyle.fill
    ..color = Color(color)
    ..isAntiAlias = true;

  static Paint _stroke(int color, double width, {bool round = false}) => Paint()
    ..style = PaintingStyle.stroke
    ..color = Color(color)
    ..strokeWidth = width
    ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static Paint _alpha(Paint base, double opacity) => Paint()
    ..style = base.style
    ..color = base.color.withValues(alpha: opacity.clamp(0.0, 1.0))
    ..strokeWidth = base.strokeWidth
    ..strokeCap = base.strokeCap
    ..strokeJoin = base.strokeJoin
    ..isAntiAlias = true;

  // Applies scale/rotate about [pivot] plus an extra translate, runs [draw],
  // then restores.
  void _applyTransformScoped(
    Canvas canvas,
    Offset pivot, {
    double tx = 0,
    double ty = 0,
    double rot = 0,
    double sx = 1,
    double sy = 1,
    required VoidCallback draw,
  }) {
    canvas.save();
    _applyTransform(canvas, pivot, tx: tx, ty: ty, rot: rot, sx: sx, sy: sy);
    draw();
    canvas.restore();
  }

  void _applyTransform(
    Canvas canvas,
    Offset pivot, {
    double tx = 0,
    double ty = 0,
    double rot = 0,
    double sx = 1,
    double sy = 1,
  }) {
    canvas.translate(pivot.dx + tx, pivot.dy + ty);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  @override
  bool shouldRepaint(covariant _ZoeMascotPainter old) =>
      old.mode != mode ||
      old.viseme != viseme ||
      old.reducedMotion != reducedMotion;
}

// ── Geometry (parsed once) ───────────────────────────────────────────────────
// Paths lifted from source-preview.html's inline SVG (viewBox 0 0 563 667).

class _MascotPaths {
  final Path body;
  final Path eyeLeft;
  final Path eyeRight;
  final Path cheekLeft;
  final Path cheekRight;
  final Path mouthDark;
  final Path mouthRed;
  final Path mouthClosed;
  final Path leafLeft;
  final Path leafRight;
  final Path stemLeft;
  final Path stemRight;
  final Path droplet1;
  final Path droplet2;
  final Path droplet3;

  _MascotPaths._({
    required this.body,
    required this.eyeLeft,
    required this.eyeRight,
    required this.cheekLeft,
    required this.cheekRight,
    required this.mouthDark,
    required this.mouthRed,
    required this.mouthClosed,
    required this.leafLeft,
    required this.leafRight,
    required this.stemLeft,
    required this.stemRight,
    required this.droplet1,
    required this.droplet2,
    required this.droplet3,
  });

  static Path _oval(double cx, double cy, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2,
        height: ry * 2,
      ));

  // Thinking droplets carry a group translate(0, -92) in the source; bake it in.
  static Path _droplet(String d) =>
      parseSvgPathData(d).shift(const Offset(0, -92));

  factory _MascotPaths.build() => _MascotPaths._(
        body: parseSvgPathData(
          'M144.372 210.686C213.572 144.286 243.5 127.553 268 127.553C285.647 127.553 289.04 125.378 325.372 148.186C361 170.553 369.167 181.607 390.872 198.186C419.5 220.053 477.872 300.52 508.872 346.186C542.206 405.686 590.572 538.486 517.372 593.686C425.872 662.686 337 655.053 325.372 657.686C313.467 660.383 232.872 659.686 212.872 657.686C192.872 655.686 167 649.053 144.372 641.686C122.788 634.66 70.0553 609.446 58.5001 597.553C39.5001 577.997 31.8721 572.186 12.8721 517.686C-2.32785 474.086 15.5388 411.52 26.3721 385.686C36.8721 355.02 75.1721 277.086 144.372 210.686Z',
        ),
        eyeLeft: _oval(168, 423.497, 30, 38),
        eyeRight: _oval(353, 423.497, 30, 38),
        cheekLeft: _oval(112.5, 502.997, 37.5, 28.5),
        cheekRight: _oval(412.5, 502.997, 37.5, 28.5),
        mouthDark: parseSvgPathData(
          'M301 468.997C271.4 484.597 232.333 475.497 216.5 468.997C213.7 467.926 212.667 473.217 212.5 475.997C210.1 487.597 215.167 505.164 218 512.497C223.167 523.33 239.3 544.197 262.5 540.997C291.5 536.997 300.5 516.497 304 508.997C307.468 501.566 308 474.997 306.5 470.997C305.3 467.797 302.333 468.33 301 468.997Z',
        ),
        mouthRed: parseSvgPathData(
          'M294.467 516.432C265.057 552.582 237.15 531.876 225.389 515.078C224.431 513.71 223.366 512.121 223.93 510.548C225.262 506.841 232.896 503.567 241.379 501.083C253.169 497.631 265.807 497.846 277.504 501.601C289.923 505.588 294.73 509.46 295.916 512.149C296.569 513.629 295.487 515.177 294.467 516.432Z',
        ),
        mouthClosed: parseSvgPathData(
          'M217 494.312C228.496 513.093 262.697 540.463 307.537 499.692',
        ),
        leafLeft: parseSvgPathData(
          'M122.881 11.5569C228.068 -19.2616 253.616 45.0915 253.499 90.0855C253.483 96.4275 249.124 101.838 243.022 103.568C147.841 130.554 116.768 70.0925 112.524 26.3526C111.865 19.5642 116.336 13.4746 122.881 11.5569Z',
        ),
        leafRight: parseSvgPathData(
          'M403.622 11.5624C298.436 -19.2561 272.887 45.0971 273.004 90.091C273.02 96.4331 277.379 101.843 283.481 103.573C378.662 130.56 409.735 70.0981 413.979 26.3581C414.638 19.5698 410.167 13.4801 403.622 11.5624Z',
        ),
        stemLeft: parseSvgPathData(
          'M264 146.997C264.5 122.164 247.7 67.4969 176.5 47.4969',
        ),
        stemRight: parseSvgPathData(
          'M264.5 145.997C258.167 128.83 268.9 84.8969 362.5 46.4969',
        ),
        droplet1: _droplet(
          'M218 44C218 44 203 66 203 78C203 91 213 101 226 101C239 101 249 91 249 78C249 66 234 44 234 44C230 37 222 37 218 44Z',
        ),
        droplet2: _droplet(
          'M272 20C272 20 257 42 257 54C257 67 267 77 280 77C293 77 303 67 303 54C303 42 288 20 288 20C284 13 276 13 272 20Z',
        ),
        droplet3: _droplet(
          'M326 44C326 44 311 66 311 78C311 91 321 101 334 101C347 101 357 91 357 78C357 66 342 44 342 44C338 37 330 37 326 44Z',
        ),
      );
}

final _MascotPaths _paths = _MascotPaths.build();
