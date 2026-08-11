// Circular topic switcher for the Home screen.
//
// A horizontally-swipeable carousel of topic circles: the centered item is
// enlarged and berry-highlighted (with a pill label), its neighbours are
// progressively smaller and fade into the garden background at the edges. The
// list loops infinitely — swiping past the last topic wraps back to the first.
// Settling on a topic reports it via [onSelect] (which the Home screen uses to
// relabel the "Let's Talk About …" CTA).

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../models/child_memory.dart';
import 'topic_handoff.dart';
import 'topic_icon.dart';

class TopicCarousel extends StatefulWidget {
  /// Topics to cycle through (recommended first). Must be non-empty.
  final List<TopicChoice> topics;

  /// The effective selection — used to place the initial centered item.
  final TopicChoice? selected;

  /// Fired when the carousel settles on a topic (user swipe).
  final ValueChanged<TopicChoice> onSelect;

  /// The topic designated as Zoe's Pick. Defaults to topics.first if omitted.
  final TopicChoice? zoePick;

  const TopicCarousel({
    super.key,
    required this.topics,
    required this.selected,
    required this.onSelect,
    this.zoePick,
  });

  @override
  State<TopicCarousel> createState() => _TopicCarouselState();
}

class _TopicCarouselState extends State<TopicCarousel> {
  // A large virtual page count so the carousel can be swiped in either
  // direction "forever"; the real topic is topics[index % length].
  static const int _loops = 1000;

  static const double _selectedCircle = 96;
  static const double _restingCircle = 68;
  static const double _selectedArtwork = 72;
  static const double _restingArtwork = 48;
  static const double _labelBox = 44;
  static const double _labelGap = 6;
  static const double _pageExtent = 106;
  static const double _arcStep = 12;
  static const double _carouselBodyHeight = 146;
  static const double _compactBreakpoint = 360;
  static const String _arcAsset =
      'assets/homescreen/new/topic-carousel-arc.svg';

  PageController? _controller;
  late final int _base;

  @override
  void initState() {
    super.initState();
    final len = widget.topics.length;
    _base = len * (_loops ~/ 2);
  }

  int get _zoePickIndex {
    final pick = widget.zoePick ?? (widget.topics.isNotEmpty ? widget.topics.first : null);
    if (pick != null) {
      final idx = widget.topics.indexWhere((t) => t.name == pick.name);
      if (idx >= 0) return idx;
    }
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= PageController(
      // The PageView itself is full-screen width, so this keeps every page
      // centre exactly 106px apart at any phone width.
      viewportFraction: _pageExtent / MediaQuery.sizeOf(context).width,
      initialPage: _base + _initialIndex(),
    );
  }

  int _initialIndex() {
    final sel = widget.selected;
    if (sel != null) {
      final i = widget.topics.indexWhere((t) => t.name == sel.name);
      if (i >= 0) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // The live (fractional) page while scrolling, else the resting page.
  double get _page {
    final controller = _controller!;
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final len = widget.topics.length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < _compactBreakpoint;
    final controller = _controller!;

    return Column(
      key: const ValueKey('home-topic-carousel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final zoeIdx = _zoePickIndex;
            final page = _page;
            final distToZoe = len > 0 ? ((page - zoeIdx) % len).abs() : 0.0;
            final normalizedDist =
                len > 0
                    ? (distToZoe > len / 2 ? len - distToZoe : distToZoe).abs()
                    : 0.0;
            final labelOpacity = (1.0 - (normalizedDist * 2)).clamp(0.0, 1.0);

            return Opacity(
              opacity: labelOpacity,
              child: Text(
                "Ella's Pick",
                key: const ValueKey('home-topic-carousel-pick-label'),
                style: EllaTextStyles.bodySmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.berryDeep,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        // Pointer aimed at the centered circle (always visible).
        const Icon(
          Icons.arrow_drop_down,
          key: ValueKey('home-topic-carousel-pointer'),
          size: 30,
          color: EllaColors.berryDark,
        ),
        SizedBox(
          height: _carouselBodyHeight,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: screenWidth,
            maxWidth: screenWidth,
            child: SizedBox(
              width: screenWidth,
              child: ShaderMask(
                // Keep the partially clipped outer topics identifiable instead
                // of fading them all the way into the scene.
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x99000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.08, 0.92, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: _selectedCircle,
                      child: IgnorePointer(
                        child: SvgPicture.asset(
                          _arcAsset,
                          key: const ValueKey('home-topic-carousel-arc'),
                          width: screenWidth,
                          height: _selectedCircle,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    PageView.builder(
                      key: const ValueKey('home-topic-carousel-page-view'),
                      controller: controller,
                      clipBehavior: Clip.none,
                      pageSnapping: false,
                      physics: SnappingScrollPhysics(
                        itemWidth: _pageExtent,
                        parent: const BouncingScrollPhysics(),
                      ),
                      onPageChanged: (index) =>
                          widget.onSelect(widget.topics[index % len]),
                      itemBuilder: (context, index) {
                        final topic = widget.topics[index % len];
                        return AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            final distance = (_page - index).abs().clamp(
                              0.0,
                              2.0,
                            );
                            final centreT = (1 - distance).clamp(0.0, 1.0);
                            final edgeT = (distance - 1).clamp(0.0, 1.0);
                            final circleSize = _lerp(
                              _restingCircle,
                              _selectedCircle,
                              centreT,
                            );
                            final artworkSize = _lerp(
                              _restingArtwork,
                              _selectedArtwork,
                              centreT,
                            );
                            final opacity = distance <= 1
                                ? _lerp(0.88, 1, centreT)
                                : compact
                                ? _lerp(0.88, 0, edgeT)
                                : _lerp(0.88, 0.55, edgeT);
                            final blurSigma = compact
                                ? 0.0
                                : _lerp(0, 0.65, edgeT);
                            final fontSize = _lerp(12, 14, centreT);
                            final isCenter = distance < 0.5;
                            final circleTop =
                                (_selectedCircle / 2) +
                                (_arcStep * distance) -
                                (circleSize / 2);

                            final item = _TopicItem(
                              topic: topic,
                              itemIndex: index,
                              isCenter: isCenter,
                              circleSize: circleSize,
                              artworkSize: artworkSize,
                              fontSize: fontSize,
                              circleTop: circleTop,
                              onTap: () {
                                if (_controller != null && _controller!.hasClients) {
                                  _controller!.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                            );

                            return Opacity(
                              key: ValueKey('home-topic-carousel-item-$index'),
                              opacity: opacity,
                              child: blurSigma == 0
                                  ? item
                                  : ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(
                                        sigmaX: blurSigma,
                                        sigmaY: blurSigma,
                                        tileMode: TileMode.decal,
                                      ),
                                      child: item,
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Swipe to change',
          style: EllaTextStyles.caption.copyWith(color: EllaColors.greenDeep),
        ),
      ],
    );
  }
}

class _TopicItem extends StatelessWidget {
  final TopicChoice topic;
  final int itemIndex;
  final bool isCenter;
  final double circleSize;
  final double artworkSize;
  final double fontSize;
  final double circleTop;
  final VoidCallback onTap;

  const _TopicItem({
    required this.topic,
    required this.itemIndex,
    required this.isCenter,
    required this.circleSize,
    required this.artworkSize,
    required this.fontSize,
    required this.circleTop,
    required this.onTap,
  });

  TextScaler _labelTextScaler(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 14 / fontSize);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: circleTop,
            left: (_TopicCarouselState._pageExtent - circleSize) / 2,
            child: HeroMode(
              enabled: isCenter,
              child: Hero(
                tag: topicHandoffHeroTag(topic),
                createRectTween: topicHandoffRectTween,
                flightShuttleBuilder: buildTopicHandoffFlight,
                child: TopicHandoffBadge(
                  key: ValueKey('home-topic-carousel-circle-$itemIndex'),
                  topic: topic,
                  size: circleSize,
                  iconSize: artworkSize,
                  selectedSource: isCenter,
                  artworkKey: ValueKey('home-topic-carousel-artwork-$itemIndex'),
                ),
              ),
            ),
          ),
          Positioned(
            top: circleTop + circleSize + _TopicCarouselState._labelGap,
            left: 0,
            right: 0,
            height: _TopicCarouselState._labelBox,
            child: Align(
              alignment: Alignment.topCenter,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: 0,
                maxWidth: isCenter ? 120 : 96,
                minHeight: 0,
                maxHeight: double.infinity,
                child: isCenter ? _pill(context) : _plainLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context) {
    return ConstrainedBox(
      key: ValueKey('home-topic-carousel-label-$itemIndex'),
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EllaColors.berryLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: EllaColors.berryDark, width: 1.5),
        ),
        child: Text(
          topic.display,
          key: ValueKey('home-topic-carousel-label-text-$itemIndex'),
          textScaler: _labelTextScaler(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: topicLabelStyle(EllaColors.berryDark, fontSize: fontSize),
        ),
      ),
    );
  }

  Widget _plainLabel(BuildContext context) {
    return ConstrainedBox(
      key: ValueKey('home-topic-carousel-label-$itemIndex'),
      constraints: const BoxConstraints(maxWidth: 96),
      child: Text(
        topic.display,
        key: ValueKey('home-topic-carousel-label-text-$itemIndex'),
        textScaler: _labelTextScaler(context),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: topicLabelStyle(EllaColors.textSecondary, fontSize: fontSize),
      ),
    );
  }
}

/// Custom snapping scroll physics that allows free momentum/flinging across
/// multiple items while ensuring the scroll always settles centered on an item.
class SnappingScrollPhysics extends ScrollPhysics {
  final double itemWidth;

  const SnappingScrollPhysics({
    required this.itemWidth,
    super.parent,
  });

  @override
  SnappingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(
      itemWidth: itemWidth,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If we're out of range, let the parent handle the overscroll bounce/clamp.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Let the parent physics determine the natural deceleration simulation.
    final Simulation? parentSimulation = super.createBallisticSimulation(position, velocity);
    
    double targetPixels;
    if (parentSimulation != null) {
      // Find where the scroll would naturally settle under friction.
      final double naturalFinalPixels = parentSimulation.x(double.infinity);
      // Snap that natural settling position to the nearest item boundary.
      targetPixels = (naturalFinalPixels / itemWidth).round() * itemWidth;
    } else {
      // No fling velocity, just snap the current position to the nearest boundary.
      targetPixels = (position.pixels / itemWidth).round() * itemWidth;
    }
    
    // Ensure we stay within the scrollable range.
    targetPixels = targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent);

    // If the target position is different, animate there with a spring.
    if (targetPixels != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        velocity,
        tolerance: toleranceFor(position),
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
