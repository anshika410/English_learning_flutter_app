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

import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
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
import '../../core/app_toast.dart';

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
      error: (e, _) => NetworkErrorView(
        onRetry: () => ref.invalidate(chatProvider),
      ),
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
  TopicChoice? get _selected => _selectedTopic ?? _recommended;

  // Server-authored recap line ("Last time…"), shown verbatim. Empty until the
  // API provides it, in which case the card shows its first-chat fallback.
  String get _recap => _memory?.lastTimeRecap ?? '';

  void _selectTopic(TopicChoice topic) => setState(() {
    _selectedTopic = topic;
    _promoteSelectedTopic = false;
  });

  // Replays the "Last time" recap aloud. Speaks the same fallback line that the
  // card shows when the server hasn't sent a recap yet. A no-op while TTS is
  // already speaking (placement-flow behavior), so taps can't stack utterances.
  Future<void> _speakRecap() async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) return;
    final text = _recap.trim().isNotEmpty
        ? _recap.trim()
        : "This is our first chat together — I can't wait!";
    setState(() {
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
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
    final picked = await Navigator.of(context).push<TopicChoice>(
      MaterialPageRoute(builder: (_) => const AllTopicsScreen()),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTopic = picked;
        _promoteSelectedTopic = true;
      });
    }
  }

  Future<void> _startSelected() async {
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
  }

  @override
  Widget build(BuildContext context) {
    // Keep the CTA tappable even while memory is still loading so it doesn't
    // visibly flip from disabled→enabled on launch; _startSelected safely no-ops
    // until chatProvider has a value. The label fills in once the topic loads.
    // The CTA shows the short label (server-authored) — the full name is only
    // used for POST /session.
    final selected = _selected;
    final selectedLabel = selected?.display ?? '';
    final ctaLabel = selectedLabel.isNotEmpty
        ? "Let's Talk About $selectedLabel"
        : "Let's Talk";
    final pickPrompt = selectedLabel.isNotEmpty
        ? 'Not the $selectedLabel? Pick your own'
        : 'Not this topic? Pick your own';

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
                    ref.watch(onboardingProvider).valueOrNull?.name ??
                    kHomeChildName,
                onOpenProfile: widget.onOpenProfile,
                onOpenGarden: widget.onOpenGarden,
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
                            mode: ZoeMascotMode.listening,
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
                          const _SectionDivider(label: 'Next Session'),
                          const SizedBox(height: 12),
                          // Short wobble whenever the selected topic changes.
                          ShakeOnChange(
                            trigger: selected?.name ?? '',
                            child: EllaPrimaryButton(
                              label: ctaLabel,
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
                              // EllaPrimaryButton plays the tap click itself.
                              onTap: _startSelected,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom group — pick-your-own prompt + topic chips.
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
          ),
        ),
      ),
    );
  }
}

// ── Header (greeting + profile / garden shortcuts) ──────────────────────────

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
            child: Text(
              'Hi, $name!',
              style: EllaTextStyles.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        : "This is our first chat together — I can't wait!";

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

// The next_topics.alternatives as chips + a "See More" chip. Tapping a topic
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
    final ordered = <TopicChoice>[];
    final sel = selected;
    final seen = <String>{};
    void addTopic(TopicChoice? topic) {
      if (topic == null || topic.name.isEmpty || !seen.add(topic.name)) return;
      ordered.add(topic);
    }

    if (promoteSelected) {
      // Move the explicit pick to the front (it may be one of the alternatives,
      // or a See-More pick that isn't — prepend either way), highlighted.
      addTopic(sel);
      for (final topic in alternatives) {
        addTopic(topic);
      }
    } else {
      addTopic(recommended);
      for (final topic in alternatives) {
        addTopic(topic);
      }
    }
    if (sel != null && sel.name.isNotEmpty) {
      final isAlreadyInAlternatives = alternatives.any((t) => t.name == sel.name);
      if (!isAlreadyInAlternatives) {
        if (ordered.isNotEmpty) {
          ordered[0] = sel;
        } else {
          ordered.add(sel);
        }
      }
    }
    final shown = ordered.take(2).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalGap = 12.0;
        const horizontalPadding = 6.0;
        const verticalPadding = 8.0;
        const iconSize = 53.0;
        const iconLabelGap = 4.0;
        final cardWidth = (constraints.maxWidth - horizontalGap * 2) / 3;
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
            verticalPadding * 2 + iconSize + iconLabelGap + rowLabelHeight;

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
                selected: sel != null && topic.name == sel.name,
                onTap: () => onSelect(topic),
              ),
            ),
          );
        }
        // Keep three equal columns even before the topics arrive.
        for (var i = shown.length; i < 2; i++) {
          slots.add(Expanded(child: _ChipPlaceholder(height: rowHeight)));
        }
        slots.add(
          Expanded(
            child: _SeeMoreChip(
              height: rowHeight,
              labelLayout: seeMoreLayout,
              labelSlotHeight: rowLabelHeight,
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
  final Widget child;
  final VoidCallback? onTap;

  const _ChipShell({
    super.key,
    required this.height,
    required this.fill,
    required this.outline,
    required this.child,
    this.outlineWidth = 1.5,
    this.onTap,
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
              playTapClick();
              tap();
            },
      child: Container(
        height: height,
        // BoxDecoration contributes its border to the content inset. Offset
        // it here so every chip keeps the same 6x8 padding and icon position,
        // including the selected chip's thicker outline.
        padding: EdgeInsets.symmetric(
          horizontal: 6 - outlineWidth,
          vertical: 8 - outlineWidth,
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
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.icon,
    required this.labelLayout,
    required this.labelSlotHeight,
    required this.height,
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
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopicIcon(
            key: ValueKey('home-topic-icon-$label'),
            icon: icon,
            size: 53,
            fallbackColor: content,
          ),
          const SizedBox(height: 4),
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
  final VoidCallback onTap;

  const _SeeMoreChip({
    required this.height,
    required this.labelLayout,
    required this.labelSlotHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      key: const ValueKey('home-see-more-chip'),
      height: height,
      fill: EllaColors.surface,
      outline: EllaColors.ink.withValues(alpha: 0.35),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/homescreen/new/BoundingBox.svg',
            key: const ValueKey('home-see-more-icon'),
            width: 53,
            height: 53,
            colorFilter: const ColorFilter.mode(
              EllaColors.berryDark,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 4),
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

  const _ChipPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) => _ChipShell(
    height: height,
    fill: EllaColors.surface.withValues(alpha: 0.5),
    outline: EllaColors.ink.withValues(alpha: 0.12),
    child: const SizedBox.shrink(),
  );
}
