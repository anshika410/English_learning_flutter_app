// Zoe mascot — the Figma circular window (brown ring + mint inner circle) from
// `assets/homescreen/window.svg`, with the animated WebP overlaid exactly over
// the inner circle so it covers the static mascot baked into the SVG.
// The mood drives which animation plays.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MascotMood {
  /// Zoe is talking (TTS playing).
  speaking,

  /// Zoe is composing a reply.
  thinking,

  /// Waiting for / hearing the child — idle loop.
  listening,

  /// Home screen greeting — playful idle loop.
  greeting,
}

const String _kMascotDir = 'assets/mascot-animations';
const String _kWindowAsset = 'assets/homescreen/window.svg';

// Inner mint circle is ~0.73 of the window diameter (from window.svg geometry).
const double _kInnerFactor = 0.73;

class ZoeMascot extends StatefulWidget {
  final MascotMood mood;
  final double size;

  const ZoeMascot({
    super.key,
    required this.mood,
    this.size = 200,
  });

  @override
  State<ZoeMascot> createState() => _ZoeMascotState();
}

class _ZoeMascotState extends State<ZoeMascot> {
  bool _altFrame = false; // toggles the second asset in idle loops
  Timer? _idleTimer;

  static const _holdDuration = Duration(seconds: 4);

  bool get _isIdleLoop =>
      widget.mood == MascotMood.listening || widget.mood == MascotMood.greeting;

  @override
  void initState() {
    super.initState();
    if (_isIdleLoop) _scheduleIdleStep();
  }

  @override
  void didUpdateWidget(ZoeMascot old) {
    super.didUpdateWidget(old);
    if (widget.mood == old.mood) return;
    if (_isIdleLoop) {
      setState(() => _altFrame = false);
      _scheduleIdleStep();
    } else {
      _idleTimer?.cancel();
      _idleTimer = null;
      if (_altFrame) setState(() => _altFrame = false);
    }
  }

  void _scheduleIdleStep() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      setState(() => _altFrame = !_altFrame);
      _scheduleIdleStep();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  String get _assetPath {
    switch (widget.mood) {
      case MascotMood.speaking:
        return '$_kMascotDir/speaking.webp';
      case MascotMood.thinking:
        return '$_kMascotDir/regular-thinking.webp';
      case MascotMood.listening:
        return _altFrame
            ? '$_kMascotDir/juggling.webp'
            : '$_kMascotDir/listening.webp';
      case MascotMood.greeting:
        return _altFrame
            ? '$_kMascotDir/bubblepop.webp'
            : '$_kMascotDir/juggling.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.size * _kInnerFactor;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            _kWindowAsset,
            width: widget.size,
            height: widget.size,
          ),
          ClipOval(
            child: SizedBox(
              width: inner,
              height: inner,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Image.asset(
                  _assetPath,
                  key: ValueKey<String>(_assetPath),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
