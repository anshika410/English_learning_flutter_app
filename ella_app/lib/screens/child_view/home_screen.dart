// Home / Talk screen — Figma "Learning Flow — Homescreen".
// An outdoor garden scene: sky + sun + rolling hills (GardenSkyBackground), the
// sprout mascot "Zoe", a greeting header with profile/garden shortcuts, a
// "Last time" recall card, the proposed-topic CTA ("Let's Talk About …"), and
// three pick-your-own topic chips. Topic + recap are derived live from memory.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/engine.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import 'session_screen.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';

// The child's display name. No name field exists on MemoryState yet (childId is
// 'demo'), so this is a swappable placeholder matching the design demo until a
// real profile name is wired through.
const String kHomeChildName = 'Maya';

const String _kMascotAsset = 'assets/homescreen/new/mascot-open.svg';

// Design-exported glyphs (Figma). Profile / family / school / see-more still use
// Material stand-ins until those are exported too.
const String _kPlantIcon = 'assets/homescreen/new/Plant.svg'; // garden shortcut
const String _kClockIcon =
    'assets/homescreen/new/ClockClockwise.svg'; // "Last time"
const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg'; // CTA

// Mascot footprint from the Figma frame (150.55×180 in a 430-wide artboard).
const double _kMascotWidthFactor = 150.55 / 430;
const double _kMascotAspect = 180 / 150.55;

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
      error: (e, _) => GardenSkyBackground(
        child: Center(
          child: Text(
            'Home error: $e',
            style: const TextStyle(color: EllaColors.ink),
          ),
        ),
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
  // pickTopic() is random for the interest-less demo, so cache the chosen topic
  // and only recompute when the relevant memory actually changes — otherwise the
  // CTA label would flicker on every rebuild.
  String? _topicSig;
  String? _topic;

  MemoryState? get _memory => widget.memory;

  String? get _stableTopic {
    final mem = _memory;
    if (mem == null) return null;
    final sig = '${mem.level}|${mem.lastTopics.join(",")}|${mem.interests}';
    if (sig != _topicSig) {
      _topicSig = sig;
      _topic = pickTopic(mem)?.topic;
    }
    return _topic;
  }

  String? get _recapTopic => (_memory != null && _memory!.lastTopics.isNotEmpty)
      ? _memory!.lastTopics.first
      : null;

  Future<void> _startTalking() async {
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
    // visibly flip from disabled→enabled on launch; _startTalking safely no-ops
    // until chatProvider has a value. The label fills in once the topic loads.
    void onStart() => _startTalking();
    final nextTopic = _stableTopic;
    final topicTitle = nextTopic != null ? _titleCase(nextTopic) : null;
    final ctaLabel = topicTitle != null
        ? "Let's Talk About $topicTitle"
        : "Let's Talk";
    final pickPrompt = topicTitle != null
        ? 'Not the $topicTitle? Pick your own'
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
                name: kHomeChildName,
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
                          SvgPicture.asset(
                            _kMascotAsset,
                            width: mascotW,
                            height: mascotW * _kMascotAspect,
                          ),
                          const SizedBox(height: 20),
                          _LastTimeCard(recapTopic: _recapTopic),
                          const SizedBox(height: 16),
                          const _SectionDivider(label: 'Next Session'),
                          const SizedBox(height: 12),
                          EllaPrimaryButton(
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
                            onTap: onStart,
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
              _TopicChipsRow(onPick: onStart),
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
            _CircleIconButton(
              // TODO: swap for the exported profile glyph when available.
              glyph: const Icon(
                Icons.person_rounded,
                size: 24,
                color: EllaColors.infoDark,
              ),
              fill: EllaColors.surfaceVariant,
              ring: EllaColors.info,
              onTap: onOpenProfile,
            ),
            const SizedBox(height: 12),
            _CircleIconButton(
              glyph: SvgPicture.asset(_kPlantIcon, width: 26, height: 26),
              fill: EllaColors.greenLight,
              ring: EllaColors.greenDark,
              onTap: onOpenGarden,
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final Widget glyph;
  final Color fill;
  final Color ring;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.glyph,
    required this.fill,
    required this.ring,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 3),
        ),
        child: glyph,
      ),
    );
  }
}

// ── "Last time" recall card ─────────────────────────────────────────────────

class _LastTimeCard extends StatelessWidget {
  final String? recapTopic;
  const _LastTimeCard({required this.recapTopic});

  @override
  Widget build(BuildContext context) {
    final body = recapTopic != null
        ? 'Last time, we talked about ${_titleCase(recapTopic!)}.'
        : "This is our first chat together — I can't wait!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EllaColors.info, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SvgPicture.asset(_kClockIcon, width: 16, height: 16),
              const SizedBox(width: 6),
              Text(
                'Last time',
                style: EllaTextStyles.caption.copyWith(color: EllaColors.info),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: EllaTextStyles.bodyBase),
        ],
      ),
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

// ── Pick-your-own topic chips ───────────────────────────────────────────────

class _TopicChipsRow extends StatelessWidget {
  final VoidCallback? onPick;
  const _TopicChipsRow({required this.onPick});

  @override
  Widget build(BuildContext context) {
    // TODO: route the chosen topic into startSession once the provider accepts a
    // topic override; for now every chip opens the standard session flow.
    return Row(
      children: [
        Expanded(
          child: _TopicChip(
            icon: Icons.groups_rounded,
            label: 'Family',
            fill: EllaColors.berryLight,
            content: EllaColors.berryDark,
            onTap: onPick,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopicChip(
            icon: Icons.school_rounded,
            label: 'School',
            fill: EllaColors.environmentLight,
            content: EllaColors.environmentDeep,
            onTap: onPick,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopicChip(
            icon: Icons.open_in_full_rounded,
            label: 'See More!',
            fill: EllaColors.surface,
            content: EllaColors.ink,
            onTap: onPick,
          ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fill;
  final Color content;
  final VoidCallback? onTap;

  const _TopicChip({
    required this.icon,
    required this.label,
    required this.fill,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: content.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: content),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EllaTextStyles.caption.copyWith(color: content),
            ),
          ],
        ),
      ),
    );
  }
}

// ── helpers ─────────────────────────────────────────────────────────────────

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
