import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../models/child_memory.dart';
import 'topic_icon.dart';

const Duration kTopicHandoffFlightDuration = Duration(milliseconds: 650);
const Duration kTopicHandoffSettleDuration = Duration(milliseconds: 360);

String topicHandoffHeroTag(TopicChoice topic) =>
    'topic-handoff:${topic.name}:${topic.icon}';

double topicHandoffRotation(double forwardProgress) =>
    -2 * math.pi * forwardProgress.clamp(0.0, 1.0);

/// Recovers the route's linear progress from the eased value supplied to a
/// Hero shuttle. Flutter wraps Hero flights in [Curves.fastOutSlowIn], which
/// would otherwise compress most of the spin into the middle of the flight.
double topicHandoffLinearFlightProgress(double heroProgress) {
  final target = heroProgress.clamp(0.0, 1.0);
  if (target == 0 || target == 1) return target;

  var lower = 0.0;
  var upper = 1.0;
  for (var i = 0; i < 16; i++) {
    final midpoint = (lower + upper) / 2;
    if (Curves.fastOutSlowIn.transform(midpoint) < target) {
      lower = midpoint;
    } else {
      upper = midpoint;
    }
  }
  return (lower + upper) / 2;
}

Widget buildTopicHandoffFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final hero = direction == HeroFlightDirection.push
      ? toHeroContext.widget as Hero
      : fromHeroContext.widget as Hero;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final forwardT = direction == HeroFlightDirection.push
          ? animation.value
          : 1 - animation.value;
      final linearT = topicHandoffLinearFlightProgress(forwardT);
      final angle = topicHandoffRotation(linearT);
      return Transform.rotate(
        key: const ValueKey('topic-handoff-flight-rotation'),
        angle: angle,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox.square(dimension: 40, child: child),
          ),
        ),
      );
    },
    child: hero.child,
  );
}

RectTween topicHandoffRectTween(Rect? begin, Rect? end) =>
    MaterialRectCenterArcTween(begin: begin, end: end);

class TopicHandoffBadge extends StatelessWidget {
  final TopicChoice topic;
  final double size;
  final double iconSize;
  final bool selectedSource;
  final Key? artworkKey;

  const TopicHandoffBadge({
    super.key,
    required this.topic,
    required this.size,
    required this.iconSize,
    this.selectedSource = false,
    this.artworkKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: EllaColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selectedSource
              ? EllaColors.berryDark
              : EllaColors.environmentDark,
          width: selectedSource ? 3 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: selectedSource ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SizedBox.square(
          key: artworkKey,
          dimension: iconSize,
          child: TopicIcon(
            icon: topic.icon,
            size: iconSize,
            fallbackColor: EllaColors.environmentDeep,
          ),
        ),
      ),
    );
  }
}

class ConversationTopicHeader extends StatefulWidget {
  final TopicChoice topic;
  final bool animateEntrance;

  const ConversationTopicHeader({
    super.key,
    required this.topic,
    required this.animateEntrance,
  });

  @override
  State<ConversationTopicHeader> createState() =>
      _ConversationTopicHeaderState();
}

class _ConversationTopicHeaderState extends State<ConversationTopicHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController = AnimationController(
    vsync: this,
    duration: kTopicHandoffSettleDuration,
  );
  late final Animation<double> _badgeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.12,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.12,
        end: 0.96,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 27,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.96,
        end: 1.04,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.04,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 18,
    ),
  ]).animate(_settleController);
  late final Animation<double> _badgeDy = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -5.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -5.0,
        end: 3.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 27,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 3.0,
        end: -2.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -2.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 18,
    ),
  ]).animate(_settleController);
  late final Animation<double> _labelOpacity = CurvedAnimation(
    parent: _settleController,
    curve: const Interval(0.15, 1, curve: Curves.easeOut),
  );

  bool _entranceScheduled = false;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceScheduled) return;
    _entranceScheduled = true;

    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion || !widget.animateEntrance) {
      _settleController.value = 1;
      return;
    }

    _settleTimer = Timer(kTopicHandoffFlightDuration, () {
      if (mounted) _settleController.forward();
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _settleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('conversation-topic-header'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          key: const ValueKey('conversation-topic-landing'),
          animation: _settleController,
          builder: (context, child) => Transform.translate(
            key: const ValueKey('conversation-topic-landing-translate'),
            offset: Offset(0, _badgeDy.value),
            child: Transform.scale(
              key: const ValueKey('conversation-topic-landing-scale'),
              scale: _badgeScale.value,
              child: child,
            ),
          ),
          child: Hero(
            tag: topicHandoffHeroTag(widget.topic),
            createRectTween: topicHandoffRectTween,
            flightShuttleBuilder: buildTopicHandoffFlight,
            child: TopicHandoffBadge(
              key: const ValueKey('conversation-topic-badge'),
              topic: widget.topic,
              size: 40,
              iconSize: 32,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FadeTransition(
            key: const ValueKey('conversation-topic-label-fade'),
            opacity: _labelOpacity,
            child: Text(
              widget.topic.display,
              key: const ValueKey('conversation-topic-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EllaTextStyles.bodySemiboldLarge.copyWith(
                color: EllaColors.environmentDeep,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
