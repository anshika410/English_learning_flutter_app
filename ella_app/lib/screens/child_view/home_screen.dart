// Home / Talk screen — Figma "Learning Flow — Homescreen".
// An outdoor garden scene: sky + sun + rolling hills (GardenSkyBackground), the
// sprout mascot "Zoe", a greeting header with profile/garden shortcuts, a
// "Last time" recall card, the selected-topic CTA ("Let's Talk About …"), and
// pick-your-own topic chips. Recap + topics come live from the memory API's
// next_topics. The child selects a topic (chip / See More) — only the CTA starts
// a session, sending the topic name to POST /session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

import '../../core/app_toast.dart';
import '../../core/offline_alert_popup.dart';
import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'all_topics_screen.dart';
import 'session_screen.dart';
import 'topic_launcher.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/shake.dart';
import 'widgets/speaker_dot_button.dart';
import 'widgets/topic_icon.dart';
import 'widgets/zoe_mascot.dart';
import 'chat_bubble.dart';
import 'widgets/network_error_view.dart';

// The child's display name. No name field exists on MemoryState yet (childId is
// 'demo'), so this is a swappable placeholder matching the design demo until a
// real profile name is wired through.
const String kHomeChildName = 'Maya';

// Design-exported glyphs (Figma). Profile / see-more still use Material
// stand-ins until those are exported too.
const String _kPlantIcon = 'assets/homescreen/new/Plant.svg'; // garden shortcut
const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg'; // CTA

// Mascot footprint from the Figma frame (150.55-wide in a 430-wide artboard).
const double _kMascotWidthFactor = 150.55 / 430;

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onConversationEnded;
  final VoidCallback? onOpenGarden;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    this.onConversationEnded,
    this.onOpenGarden,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _HomeBody(
        memory: s.memory,
        onConversationEnded: onConversationEnded,
        onOpenGarden: onOpenGarden,
        onOpenProfile: onOpenProfile,
      ),
      loading: () => _HomeBody(
        memory: null,
        onConversationEnded: onConversationEnded,
        onOpenGarden: onOpenGarden,
        onOpenProfile: onOpenProfile,
      ),
      error: (e, _) =>
          NetworkErrorView(onRetry: () => ref.invalidate(chatProvider)),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  final MemoryState? memory;
  final VoidCallback? onConversationEnded;
  final VoidCallback? onOpenGarden;
  final VoidCallback? onOpenProfile;

  const _HomeBody({
    required this.memory,
    required this.onConversationEnded,
    required this.onOpenGarden,
    required this.onOpenProfile,
  });

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  // The topic the CTA will start. Null means "use the server's recommended".
  // Tapping an alternative chip or picking one in See More sets this; it never
  // starts a session — only the CTA does.
  TopicChoice? _selectedTopic;
  bool _promoteSelectedTopic = true;
  bool _isStarting =
      false; // guard against double-tap creating duplicate sessions

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  @override
  void initState() {
    super.initState();
    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted && _speaking) {
        setState(() {
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    super.dispose();
  }

  MemoryState? get _memory => widget.memory;

  // Server recommendation and the alternatives shown as chips.
  TopicChoice? get _recommended => _memory?.nextTopics.recommended;

  List<TopicChoice> get _alternatives =>
      _memory?.nextTopics.alternatives ?? const [];

  // The effective selection driving the CTA (explicit pick, else recommended).
  TopicChoice? get _selected {
    final explicit = _selectedTopic;
    final recommended = _recommended;
    if (explicit != null &&
        [
          ?recommended,
          ..._alternatives,
        ].any((topic) => topic.name == explicit.name)) {
      return explicit;
    }
    return recommended;
  }

  // Server-authored recap line ("Last time…"), shown verbatim. Empty until the
  // API provides it, in which case the card shows its first-chat fallback.
  String get _recap {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      return "I'm having trouble connecting right now. Check your internet and try again";
    }
    return _memory?.lastTimeRecap ?? '';
  }

  void _selectTopic(TopicChoice topic) {
    ref.read(audioProvider).playSfx(Sounds.topic);
    setState(() {
      _selectedTopic = topic;
      _promoteSelectedTopic = false;
    });
  }

  // The garden needs live data (it fetches from the API), so opening it offline
  // would only land on the error view. Block navigation and surface a snackbar
  // instead so the offline state stays on the calmer Home screen.
  void _handleOpenGarden() {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      showEllaErrorToast(
        context,
        "You're offline. Connect to the internet to visit your garden",
      );
      return;
    }
    widget.onOpenGarden?.call();
  }

  // Replays the "Last time" recap aloud. Speaks the same fallback line that the
  // card shows when the server hasn't sent a recap yet. A no-op while TTS is
  // already speaking (placement-flow behavior), so taps can't stack utterances.
  Future<void> _speakRecap() async {
    final tts = ref.read(ttsProvider);
    if (_speaking) {
      await tts.stop();
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
      return;
    }
    final text = _recap.trim().isNotEmpty
        ? _recap.trim()
        : 'Ready for your first chat?';
    setState(() {
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    AnalyticsService.logTodayRecapOpened();
    AnalyticsService.logDailyRecapOpened();
    try {
      await tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _openSeeMore() async {
    final homescreenTopics = getHomescreenTopics(
      recommended: _recommended,
      alternatives: _alternatives,
      selected: _selected,
      promoteSelected: _promoteSelectedTopic,
    );
    final excludeNames = homescreenTopics.map((t) => t.name).toList();

    final picked = await Navigator.of(context).push<TopicChoice>(
      MaterialPageRoute(
        builder: (_) => AllTopicsScreen(excludeTopicNames: excludeNames),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTopic = picked;
        _promoteSelectedTopic = true;
      });
    }
  }

  Future<void> _startSelected() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final sel = _selected;
      if (sel != null && sel.name.isNotEmpty) {
        // The topic NAME (not the label) is what the backend expects.
        await startTopicByName(
          context,
          ref,
          sel.name,
          onConversationEnded: widget.onConversationEnded,
        );
        return;
      }
      // No recommendation yet — fall back to the engine's own topic pick.
      final chatState = ref.read(chatProvider);
      if (chatState.hasValue && chatState.requireValue.sessionEnded) {
        await ref.read(chatProvider.notifier).nextChat();
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScreen(onEnded: widget.onConversationEnded),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    // Keep the CTA tappable even while memory is still loading so it doesn't
    // visibly flip from disabled→enabled on launch; _startSelected safely no-ops
    // until chatProvider has a value. The label fills in once the topic loads.
    // The CTA shows the short label (server-authored) — the full name is only
    // used for POST /session.
    final selected = _selected;
    final selectedLabel = selected?.display ?? '';
    final ctaLabel = selectedLabel.isNotEmpty
        ? 'Talk about $selectedLabel'
        : 'Start Talking';
    const pickPrompt = 'Want a different topic?';

    final mascotW = (MediaQuery.of(context).size.width * _kMascotWidthFactor)
        .clamp(128.0, 168.0);

    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              _HeaderRow(
                name:
                    ref.watch(onboardingProvider).valueOrNull?.firstName ??
                        kHomeChildName,
                onOpenProfile: widget.onOpenProfile,
                onOpenGarden: _handleOpenGarden,
              ),
              // Upper group (mascot + Last-time + Next-Session + CTA), centred in
              // the space above the chips; scrolls on short screens. The
              // ConstrainedBox + centred Column genuinely centres the content
              // (a plain Center around a SingleChildScrollView would top-align it).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ZoeMascot(
                            mode: !isOnline
                                ? ZoeMascotMode.sleep
                                : ZoeMascotMode.listening,
                            size: mascotW,
                            reducedMotion: MediaQuery.of(
                              context,
                            ).disableAnimations,
                          ),
                          const SizedBox(height: 20),
                          _LastTimeCard(
                            recap: _recap,
                            onSpeak: _speakRecap,
                            highlightStart: _highlightStart,
                            highlightEnd: _highlightEnd,
                            speaking: _speaking,
                          ),
                          const SizedBox(height: 16),
                          const _SectionDivider(label: 'Up Next'),
                          const SizedBox(height: 12),
                          // Short wobble whenever the selected topic changes.
                          ShakeOnChange(
                            trigger: selected?.name ?? '',
                            child: EllaPrimaryButton(
                              label: ctaLabel,
                              labelChild: _TalkAboutCtaLabel(
                                topicLabel: selectedLabel,
                              ),
                              leading: SvgPicture.asset(
                                _kVoiceIcon,
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  EllaColors.onPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              height: 60,
                              playTapClickSound: false,
                              backgroundColor: isOnline
                                  ? null
                                  : Colors.grey[400],
                              edgeColor: isOnline ? null : Colors.grey[600],
                              onTap: isOnline
                                  ? _startSelected
                                  : () {
                                      ref
                                          .read(audioProvider)
                                          .playSfx(Sounds.error);
                                      OfflineAlertPopup.show(context);
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom group — pick-your-own prompt + topic chips. Hidden while
              // offline: topics can't load, so the row would show empty
              // placeholders that read as broken. The sleeping mascot, offline
              // recap, and disabled CTA already convey the paused state.
              if (isOnline) ...[
                const SizedBox(height: 8),
                Text(
                  pickPrompt,
                  style: EllaTextStyles.caption.copyWith(
                    color: EllaColors.greenDeep,
                  ),
                ),
                const SizedBox(height: 10),
                _TopicChipsRow(
                  // Pass the EFFECTIVE selection (explicit pick, else the
                  // server's recommended) so the topic on the "Let's Talk About…"
                  // CTA is the first, highlighted chip in the row below.
                  recommended: _recommended,
                  alternatives: _alternatives,
                  selected: _selected,
                  promoteSelected: _promoteSelectedTopic,
                  onSelect: _selectTopic,
                  onSeeMore: _openSeeMore,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header (greeting + profile / garden shortcuts) ──────────────────────────

class _TalkAboutCtaLabel extends StatelessWidget {
  final String topicLabel;

  const _TalkAboutCtaLabel({required this.topicLabel});

  static const String _prefix = 'Talk about';

  TextStyle _style() {
    return EllaTextStyles.button.copyWith(
      color: EllaColors.onPrimary,
      height: 1.15,
    );
  }

  bool _fitsOneLine(BuildContext context, String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style()),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style();
    final topic = topicLabel.trim();
    if (topic.isEmpty) {
      return Text(
        'Start Talking',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: style,
      );
    }

    final fullLabel = '$_prefix $topic';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_fitsOneLine(context, fullLabel, constraints.maxWidth)) {
          return Text(
            fullLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: style,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _prefix,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: style,
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  topic,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: style,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String name;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenGarden;

  const _HeaderRow({
    required this.name,
    required this.onOpenProfile,
    required this.onOpenGarden,
  });

  @override
  Widget build(BuildContext context) {
    // Profile sits above the garden shortcut on the right (Figma stacks them
    // vertically), with the greeting filling the left.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name!',
                  style: EllaTextStyles.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            EllaCircleIconButton(
              // TODO: swap for the exported profile glyph when available.
              glyph: const Icon(
                Icons.person_rounded,
                size: 30,
                color: EllaColors.infoDark,
              ),
              fill: EllaColors.surfaceVariant,
              ring: EllaColors.info,
              label: 'Profile',
              labelColor: EllaColors.infoDark,
              onTap: onOpenProfile,
            ),
            const SizedBox(height: 12),
            EllaCircleIconButton(
              glyph: SvgPicture.asset(_kPlantIcon, width: 32, height: 32),
              fill: EllaColors.greenLight,
              ring: EllaColors.greenDark,
              label: 'Garden',
              labelColor: EllaColors.greenDeep,
              onTap: onOpenGarden,
            ),
          ],
        ),
      ],
    );
  }
}

// ── "Last time" recall card ─────────────────────────────────────────────────

class _LastTimeCard extends StatelessWidget {
  // Server-authored recap text (memory.last_time_recap). Empty on a first chat
  // or before the API provides it, when the friendly fallback is shown instead.
  final String recap;

  /// Replays the recap aloud (TTS). Powers the speaker dot on the card, the
  /// same control that straddles Zoe's chat bubble.
  final VoidCallback onSpeak;
  final int highlightStart;
  final int highlightEnd;
  final bool speaking;

  const _LastTimeCard({
    required this.recap,
    required this.onSpeak,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = recap.trim().isNotEmpty
        ? recap.trim()
        : 'Ready for your first chat?';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EllaColors.info, width: 2),
      ),
      child: TypewriterText(
        text: body,
        style: EllaTextStyles.bodySemibold,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
        animate: false,
      ),
    );

    // Speaker dot straddling the top-right border — identical control to Zoe's
    // chat bubble. Top padding keeps the overhanging dot inside the Stack's
    // bounds so it stays tappable.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: card),
        Positioned(
          top: 0,
          right: 10,
          child: SpeakerDotButton(active: speaking, onTap: onSpeak),
        ),
      ],
    );
  }
}

// ── Labelled section divider ("Next Session", …) ────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: EllaColors.greenDeep, height: 2, thickness: 1.5),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: EllaTextStyles.caption.copyWith(color: EllaColors.greenDeep),
          ),
        ),
        line,
      ],
    );
  }
}

// ── Pick-your-own topic chips (select, don't start) ─────────────────────────

// The next_topics alternatives as chips + a "See More" chip. Tapping a topic
// chip SELECTS it (highlight + reorder to front + CTA relabel) — it does not
// start a session; only the CTA does. The effective selection (explicit pick,
// else the server's recommended — i.e. whatever the CTA points at) is moved to
// the front and highlighted, so the CTA's topic is always the first chip. Empty
// slots stay as neutral placeholders so the row's layout doesn't jump before
// the topics load.
class _TopicChipsRow extends StatelessWidget {
  final TopicChoice? recommended;
  final List<TopicChoice> alternatives;
  final TopicChoice?
  selected; // effective selection (CTA topic), highlighted first
  final bool promoteSelected;
  final ValueChanged<TopicChoice> onSelect;
  final VoidCallback onSeeMore;

  const _TopicChipsRow({
    required this.recommended,
    required this.alternatives,
    required this.selected,
    required this.promoteSelected,
    required this.onSelect,
    required this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    final shown = getHomescreenTopics(
      recommended: recommended,
      alternatives: alternatives,
      selected: selected,
      promoteSelected: promoteSelected,
    );
    final sel = selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalGap = 8.0;
        final cardWidth = (constraints.maxWidth - horizontalGap * 2) / 3;
        final horizontalPadding = responsiveTopicHorizontalPadding(
          context,
          labels: [...shown.map((topic) => topic.display), 'See More!'],
          cardWidth: cardWidth,
          singleLineLabels: const ['See More!'],
        );
        final labelWidth = cardWidth - horizontalPadding * 2;
        final topicLayouts = [
          for (final topic in shown)
            measureTopicLabel(
              context,
              text: topic.display,
              maxWidth: labelWidth,
            ),
        ];
        final seeMoreLayout = measureTopicLabel(
          context,
          text: 'See More!',
          maxWidth: labelWidth,
          allowWrap: false,
        );
        var rowLabelHeight = seeMoreLayout.height;
        for (final layout in topicLayouts) {
          if (layout.height > rowLabelHeight) rowLabelHeight = layout.height;
        }
        final rowHeight =
            kTopicCardVerticalPadding * 2 +
            kTopicIconSize +
            kTopicIconLabelGap +
            rowLabelHeight;

        final slots = <Widget>[];
        for (var i = 0; i < shown.length; i++) {
          final topic = shown[i];
          slots.add(
            Expanded(
              child: _TopicChip(
                label: topic.display,
                icon: topic.icon,
                labelLayout: topicLayouts[i],
                labelSlotHeight: rowLabelHeight,
                height: rowHeight,
                horizontalPadding: horizontalPadding,
                selected: sel != null && topic.name == sel.name,
                onTap: () => onSelect(topic),
              ),
            ),
          );
        }
        // Keep three equal columns even before the topics arrive.
        for (var i = shown.length; i < 2; i++) {
          slots.add(
            Expanded(
              child: _ChipPlaceholder(
                height: rowHeight,
                horizontalPadding: horizontalPadding,
              ),
            ),
          );
        }
        slots.add(
          Expanded(
            child: _SeeMoreChip(
              height: rowHeight,
              labelLayout: seeMoreLayout,
              labelSlotHeight: rowLabelHeight,
              horizontalPadding: horizontalPadding,
              onTap: onSeeMore,
            ),
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: horizontalGap),
              slots[i],
            ],
          ],
        );
      },
    );
  }
}

class _ChipShell extends StatelessWidget {
  final double height;
  final Color fill;
  final Color outline;
  final double outlineWidth;
  final double horizontalPadding;
  final Widget child;
  final VoidCallback? onTap;
  final bool playTapClickSound;

  const _ChipShell({
    super.key,
    required this.height,
    required this.fill,
    required this.outline,
    required this.horizontalPadding,
    required this.child,
    this.outlineWidth = 1.5,
    this.onTap,
    this.playTapClickSound = true,
  });

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Leaf gesture for every chip — play the tap click here so callers pass
      // plain callbacks (no double click).
      onTap: tap == null
          ? null
          : () {
              if (playTapClickSound) {
                playTapClick();
              }
              tap();
            },
      child: Container(
        height: height,
        // BoxDecoration contributes its border to the content inset. Offset
        // it here so every chip keeps the same 12px padding and icon position,
        // including the selected chip's thicker outline.
        padding: EdgeInsets.fromLTRB(
          horizontalPadding - outlineWidth,
          kTopicCardVerticalPadding - outlineWidth,
          horizontalPadding - outlineWidth,
          kTopicCardVerticalPadding - outlineWidth,
        ),
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outline, width: outlineWidth),
        ),
        child: child,
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final String icon;
  final TopicLabelLayout labelLayout;
  final double labelSlotHeight;
  final double height;
  final double horizontalPadding;
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.icon,
    required this.labelLayout,
    required this.labelSlotHeight,
    required this.height,
    required this.horizontalPadding,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected chips render their label in the highlight colour so the active
    // choice reads clearly; unselected stay ink. The per-topic icon (from the
    // memory API's `icon` id) shows when known, else a generic chat glyph.
    final content = selected ? EllaColors.berryDark : EllaColors.ink;
    return _ChipShell(
      key: ValueKey('home-topic-chip-$label'),
      height: height,
      fill: selected ? EllaColors.berryLight : EllaColors.surface,
      outline: selected
          ? EllaColors.berryDark
          : EllaColors.ink.withValues(alpha: 0.2),
      outlineWidth: selected ? 2.5 : 1.5,
      horizontalPadding: horizontalPadding,
      onTap: onTap,
      playTapClickSound: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopicIcon(
            key: ValueKey('home-topic-icon-$label'),
            icon: icon,
            size: kTopicIconSize,
            fallbackColor: content,
          ),
          const SizedBox(height: kTopicIconLabelGap),
          TopicCardLabel(
            key: ValueKey('home-topic-label-$label'),
            text: label,
            color: content,
            layout: labelLayout,
            slotHeight: labelSlotHeight,
          ),
        ],
      ),
    );
  }
}

class _SeeMoreChip extends StatelessWidget {
  final double height;
  final TopicLabelLayout labelLayout;
  final double labelSlotHeight;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _SeeMoreChip({
    required this.height,
    required this.labelLayout,
    required this.labelSlotHeight,
    required this.horizontalPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      key: const ValueKey('home-see-more-chip'),
      height: height,
      fill: EllaColors.surface,
      outline: EllaColors.ink.withValues(alpha: 0.35),
      horizontalPadding: horizontalPadding,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/homescreen/new/BoundingBox.svg',
            key: const ValueKey('home-see-more-icon'),
            width: kTopicIconSize,
            height: kTopicIconSize,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            colorFilter: const ColorFilter.mode(
              EllaColors.berryDark,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: kTopicIconLabelGap),
          TopicCardLabel(
            key: const ValueKey('home-see-more-label'),
            text: 'See More!',
            color: EllaColors.ink,
            layout: labelLayout,
            slotHeight: labelSlotHeight,
          ),
        ],
      ),
    );
  }
}

class _ChipPlaceholder extends StatelessWidget {
  final double height;
  final double horizontalPadding;

  const _ChipPlaceholder({
    required this.height,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) => _ChipShell(
    height: height,
    fill: EllaColors.surface.withValues(alpha: 0.5),
    outline: EllaColors.ink.withValues(alpha: 0.12),
    horizontalPadding: horizontalPadding,
    child: const SizedBox.shrink(),
  );
}

List<TopicChoice> getHomescreenTopics({
  required TopicChoice? recommended,
  required List<TopicChoice> alternatives,
  required TopicChoice? selected,
  required bool promoteSelected,
}) {
  final ordered = <TopicChoice>[];
  final seen = <String>{};
  void addTopic(TopicChoice? topic) {
    if (topic == null || topic.name.isEmpty || !seen.add(topic.name)) return;
    ordered.add(topic);
  }

  if (promoteSelected) {
    addTopic(selected);
    for (final topic in alternatives) {
      addTopic(topic);
    }
  } else {
    addTopic(recommended);
    for (final topic in alternatives) {
      addTopic(topic);
    }
  }
  if (selected != null && selected.name.isNotEmpty) {
    final isAlreadyInAlternatives = alternatives.any(
      (t) => t.name == selected.name,
    );
    if (!isAlreadyInAlternatives) {
      if (ordered.isNotEmpty) {
        ordered[0] = selected;
      } else {
        ordered.add(selected);
      }
    }
  }
  return ordered.take(2).toList();
}
