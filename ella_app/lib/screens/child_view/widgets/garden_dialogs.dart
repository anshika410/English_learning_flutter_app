// Garden detail dialogs — Figma-styled cards opened by tapping a plant or unit.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../models/garden.dart';
import '../../../services/audio_service.dart';
import 'topic_icon.dart';

const Color _sheetSurface = Color(0xFFFFFDF4);
const Color _sheetBorder = Color(0xFF9DB8AE);
const Color _ink = EllaColors.ink;
const Color _woodNail = Color(0xFF3A2010);
const Color _sectionTitle = Color(0xFF8C725B);
const Color _emptyPrompt = Color(0xFF7A4400);

const double _sheetBoardHeight = 40;
const double _sheetBoardWidthFactor = 0.7;
const double _sheetBoardNailEdgeInset = 14;
const double _sheetBoardNailSize = 6;
const double _sheetCloseGap = 24;
final ValueListenable<bool> _neverExpanded = ValueNotifier<bool>(false);

const String _tileAsset = 'assets/gardent-view/tiles.svg';
const String _talkIconAsset = 'assets/information-box/talk-svgrepo-com.svg';
const String _quoteIconAsset = 'assets/information-box/quote-mark.svg';
const String _unitFallbackIcon = 'assets/information-box/unit-globe.svg';

/// True while a garden skill/unit sheet is on screen. The garden screen listens
/// to this so it can fully hide the "Pick a Topic" CTA behind the sheet (rather
/// than leaving it dimmed under the dialog barrier).
final ValueNotifier<bool> gardenSheetOpen = ValueNotifier<bool>(false);

/// Short "time ago" label for an evidence timestamp, e.g. "2 days ago".
/// Returns null when there is no timestamp to show.
String? _relativeTime(DateTime? dt) {
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 1) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  if (diff.inHours >= 1) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inMinutes >= 1) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  return 'just now';
}

Future<void> showSkillSheet(
  BuildContext context,
  GardenStep step,
  GardenSkill skill, {
  bool isPreviousGarden = false,
}) {
  final evidenceExpanded = ValueNotifier<bool>(false);
  return _showGardenSheet(
    context,
    expandCard: evidenceExpanded,
    child: _SkillSheetBody(
      skill: skill,
      isPreviousGarden: isPreviousGarden,
      onEvidenceExpanded: () => evidenceExpanded.value = true,
    ),
  ).whenComplete(evidenceExpanded.dispose);
}

Future<void> showUnitSheet(
  BuildContext context,
  GardenData data,
  GardenStep step, {
  bool isPreviousGarden = false,
}) {
  return _showGardenSheet(
    context,
    child: _UnitSheetBody(step: step, isPreviousGarden: isPreviousGarden),
  );
}

// ── Shared Figma card shell ─────────────────────────────────────────────────

/// A garden sheet: a centered card straddled by the empty wooden board, with a
/// round close button, tap-outside / swipe-down dismissal. The [child] lays out
/// its own sticky header + scrollable body (see [_SkillSheetBody]).
Future<void> _showGardenSheet(
  BuildContext context, {
  required Widget child,
  ValueListenable<bool>? expandCard,
}) {
  gardenSheetOpen.value = true;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The card grows with its content, but never takes space
                // reserved for the board overlap, close-control gap, or the
                // 48px close control itself.
                final availableHeight = constraints.maxHeight;
                final reservedHeight =
                    (_sheetBoardHeight / 2) + _sheetCloseGap + 48;
                final preferredCardHeight = availableHeight * 0.78;
                final maxHeightForCard = availableHeight - reservedHeight;
                final maxSheetHeight = preferredCardHeight < maxHeightForCard
                    ? preferredCardHeight
                    : maxHeightForCard;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        // Swipe the card down to dismiss.
                        onVerticalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0) > 320) {
                            Navigator.of(ctx).maybePop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: expandCard ?? _neverExpanded,
                                  builder: (context, expanded, _) =>
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: maxSheetHeight,
                                        ),
                                        child: _GardenSheetCard(child: child),
                                      ),
                                ),
                                const _SheetBoard(),
                              ],
                            ),
                            const SizedBox(height: _sheetCloseGap),
                            const _SheetCloseButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  ).whenComplete(() => gardenSheetOpen.value = false);
}

class _GardenSheetCard extends StatelessWidget {
  final Widget child;
  const _GardenSheetCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-sheet-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: _sheetBoardHeight / 2),
      padding: const EdgeInsets.fromLTRB(16, _sheetBoardHeight + 8, 16, 24),
      clipBehavior: Clip.antiAlias,
      decoration: ellaSmoothDecoration(
        color: _sheetSurface,
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _sheetBorder),
      ),
      child: child,
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('garden-sheet-close'),
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(() => Navigator.of(context).maybePop()),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: _sheetSurface,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: _sheetBorder)),
        ),
        child: const Icon(Icons.close_rounded, size: 24, color: _ink),
      ),
    );
  }
}

/// The small empty carved-wood plank straddling the top edge of the sheet.
/// 70% of the sheet's width, centered, with a nail at each end.
class _SheetBoard extends StatelessWidget {
  const _SheetBoard();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _sheetBoardWidthFactor,
      child: Container(
        key: const ValueKey('garden-sheet-board'),
        height: _sheetBoardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC49050),
              Color(0xFF9B6828),
              Color(0xFFB08040),
              Color(0xFF966828),
              Color(0xFF8A5712),
            ],
            stops: [0, 0.28, 0.55, 0.78, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B1D12).withValues(alpha: 0.32),
              offset: const Offset(0, 5),
              blurRadius: 5,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.22),
              offset: const Offset(0, 2),
              blurRadius: 3,
              blurStyle: BlurStyle.inner,
            ),
            BoxShadow(
              color: const Color(0xFF3A2010).withValues(alpha: 0.2),
              offset: const Offset(0, -2),
              blurRadius: 4,
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: _sheetBoardNailEdgeInset,
              top: (_sheetBoardHeight - _sheetBoardNailSize) / 2,
              child: _NailDot(key: ValueKey('garden-sheet-left-nail')),
            ),
            Positioned(
              right: _sheetBoardNailEdgeInset,
              top: (_sheetBoardHeight - _sheetBoardNailSize) / 2,
              child: _NailDot(key: ValueKey('garden-sheet-right-nail')),
            ),
          ],
        ),
      ),
    );
  }
}

class _NailDot extends StatelessWidget {
  const _NailDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _sheetBoardNailSize,
      height: _sheetBoardNailSize,
      decoration: BoxDecoration(
        color: _woodNail,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            offset: const Offset(0.5, 0.5),
            blurRadius: 0.5,
          ),
        ],
      ),
    );
  }
}

class _WoodDivider extends StatelessWidget {
  const _WoodDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-sheet-divider'),
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFC49050),
            Color(0xFF9B6828),
            Color(0xFFB08040),
            Color(0xFF966828),
            Color(0xFF8A5712),
          ],
          stops: [0, 0.28, 0.55, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2010).withValues(alpha: 0.2),
            offset: const Offset(0, -2),
            blurRadius: 4,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22),
            offset: const Offset(0, 2),
            blurRadius: 3,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
    );
  }
}

// ── Icon resolution ─────────────────────────────────────────────────────────

const Map<String, String> _knownIconAssets = {
  'clock': 'assets/information-box/clock.svg',
  'flower': 'assets/information-box/flower.svg',
  'talk-svgrepo-com': _talkIconAsset,
  'people-who-support-svgrepo-com':
      'assets/information-box/people-who-support-svgrepo-com 1.svg',
  'people-who-support-svgrepo-com 1':
      'assets/information-box/people-who-support-svgrepo-com 1.svg',
  'u1-globe': _unitFallbackIcon,
  'u1-globe 1': _unitFallbackIcon,
  'u1-globe 2': _unitFallbackIcon,
  'globe': _unitFallbackIcon,
  'unit-globe': _unitFallbackIcon,
  'u2-past-clock': 'assets/information-box/clock.svg',
  'signs-svgrepo-com': 'assets/information-box/clock.svg',
};

String _resolveIconAsset(String raw, String fallbackAsset) {
  final value = raw.trim();
  if (value.isEmpty) return fallbackAsset;
  if (value.startsWith('assets/')) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final normalized = value
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'\.svg$'), '');
  final mapped = _knownIconAssets[normalized];
  if (mapped != null) return mapped;
  if (kBundledTopicIcons.contains(normalized)) {
    return 'assets/topic-icons/$normalized.svg';
  }
  if (normalized.startsWith('topic-icons/')) return 'assets/$normalized.svg';
  if (normalized.startsWith('information-box/')) {
    return 'assets/$normalized.svg';
  }
  return fallbackAsset;
}

class _ResolvedSvgIcon extends StatelessWidget {
  final String rawIcon;
  final String fallbackAsset;
  final double size;

  const _ResolvedSvgIcon({
    super.key,
    required this.rawIcon,
    required this.fallbackAsset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _resolveIconAsset(rawIcon, fallbackAsset);
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return SvgPicture.network(
        asset,
        width: size,
        height: size,
        placeholderBuilder: (_) =>
            SvgPicture.asset(fallbackAsset, width: size, height: size),
      );
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}

// ── Skill sheet body ────────────────────────────────────────────────────────

class _SkillSheetBody extends StatelessWidget {
  final GardenSkill skill;
  final VoidCallback? onEvidenceExpanded;

  /// Previous (completed) gardens have no sessions to start, so a skill
  /// without evidence ends at the stepper — no divider, no tile icon, no
  /// "grow this skill" prompt. Evidence, when present, is always shown.
  final bool isPreviousGarden;
  const _SkillSheetBody({
    required this.skill,
    this.isPreviousGarden = false,
    this.onEvidenceExpanded,
  });

  @override
  Widget build(BuildContext context) {
    // Latest-first so the freshest evidence is the one shown collapsed.
    final evidence = [...skill.evidence]
      ..sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    final hasBody = evidence.isNotEmpty || !isPreviousGarden;

    // The header (skill title, strand tag, stepper) stays pinned; only the
    // evidence list below the wood divider scrolls.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ResolvedSvgIcon(
              key: ValueKey('garden-skill-sheet-icon-${skill.id}'),
              rawIcon: skill.icon,
              fallbackAsset: skill.strand.icon,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.displayText,
                style: EllaFonts.bricolage(
                  const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.018,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_StrandChip(strand: skill.strand)],
        ),
        const SizedBox(height: 20),
        _SkillStepper(currentIndex: _growthIndexFor(skill)),
        if (hasBody) ...[const SizedBox(height: 16), const _WoodDivider()],
      ],
    );

    if (!hasBody) {
      return header;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: 20),
        Flexible(
          child: SingleChildScrollView(
            key: const ValueKey('garden-skill-evidence-scroll'),
            child: evidence.isEmpty
                ? const _EmptySkillState()
                : _EvidenceSection(
                    skill: skill,
                    evidence: evidence,
                    onExpanded: onEvidenceExpanded,
                  ),
          ),
        ),
      ],
    );
  }
}

class _StrandChip extends StatelessWidget {
  final Strand strand;
  const _StrandChip({required this.strand});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('garden-strand-chip-${strand.name}'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: strand.tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          strand.label,
          style: EllaFonts.bricolage(
            TextStyle(
              fontSize: 12,
              height: 1.6,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.048,
              color: strand.tagColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skill progress stepper ──────────────────────────────────────────────────

class _GrowthStage {
  final String key;
  final String label;
  final String asset;
  const _GrowthStage({
    required this.key,
    required this.label,
    required this.asset,
  });
}

/// The four growth stages, in order.
const List<_GrowthStage> _growthStages = [
  _GrowthStage(
    key: 'seed',
    label: 'Seed',
    asset: 'assets/information-box/growth-stage-seed.svg',
  ),
  _GrowthStage(
    key: 'sprout',
    label: 'Sprout',
    asset: 'assets/information-box/growth-stage-sprout.svg',
  ),
  _GrowthStage(
    key: 'bud',
    label: 'Bud',
    asset: 'assets/information-box/growth-stage-bud.svg',
  ),
  _GrowthStage(
    key: 'bloom',
    label: 'Bloom',
    asset: 'assets/information-box/growth-stage-bloom.svg',
  ),
];

/// Index into [_growthStages] for a skill's current stage.
int _growthIndexFor(GardenSkill skill) {
  if (skill.status == SkillStatus.owned || skill.sightings >= 3) return 3;
  if (skill.sightings == 2) return 2;
  if (skill.sightings == 1) return 1;
  return 0;
}

const Color _stepDone = EllaColors.greenDeep;
const Color _stepCurrent = EllaColors.berryDeep;
const Color _stepIdle = Color(0xFFD8D2C6);
const Color _stepIdleLabel = Color(0xFFA8A296);

/// Horizontal Seed → Sprout → Bud → Bloom progress rail. Stages before
/// [currentIndex] read as completed (check badge), [currentIndex] is ringed,
/// later stages are idle/greyed.
class _SkillStepper extends StatelessWidget {
  final int currentIndex;
  const _SkillStepper({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final nodes = <Widget>[];
    for (var i = 0; i < _growthStages.length; i++) {
      if (i != 0) {
        nodes.add(_StepConnector(done: i - 1 < currentIndex));
      }
      nodes.add(
        _StepNode(
          stage: _growthStages[i],
          index: i,
          currentIndex: currentIndex,
        ),
      );
    }
    return Row(
      key: const ValueKey('garden-skill-stepper'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes,
    );
  }
}

/// Fills the entire gap between two 48px node circles so the line meets
/// both circle edges with no visible margin.
class _StepConnector extends StatelessWidget {
  final bool done;
  const _StepConnector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        // Align to the vertical centre of the 48px node circles above the labels.
        margin: const EdgeInsets.only(top: 23),
        height: 2,
        color: done ? _stepDone : _stepIdle,
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final _GrowthStage stage;
  final int index;
  final int currentIndex;
  const _StepNode({
    required this.stage,
    required this.index,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final done = index < currentIndex;
    final current = index == currentIndex;
    final labelColor = current
        ? _ink
        : done
        ? _stepDone
        : _stepIdleLabel;

    return SizedBox(
      key: ValueKey('garden-step-${stage.key}'),
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: current
                        ? EllaColors.berryLight
                        : EllaColors.fieldLight,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: _stepCurrent, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: (done || current) ? 1 : 0.45,
                      child: SvgPicture.asset(
                        stage.asset,
                        width: 38,
                        height: 38,
                      ),
                    ),
                  ),
                ),
                if (done)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: _stepDone,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            style: EllaFonts.body(
              TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatefulWidget {
  final GardenSkill skill;
  final VoidCallback? onExpanded;

  /// Latest-first list of every recorded evidence for this skill. The newest is
  /// shown by default; the rest reveal inline via the "see more" link.
  final List<GardenEvidence> evidence;
  const _EvidenceSection({
    required this.skill,
    required this.evidence,
    this.onExpanded,
  });

  @override
  State<_EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends State<_EvidenceSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final evidence = widget.evidence;
    final visibleCount = _expanded ? evidence.length : 1;
    final remaining = evidence.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SvgPicture.asset(_talkIconAsset, width: 32, height: 32),
            const SizedBox(width: 12),
            Text(
              'You used this',
              style: EllaFonts.body(
                const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: _sectionTitle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < visibleCount; i++) ...[
          _EvidenceBox(
            key: ValueKey('garden-evidence-card-$i'),
            evidence: evidence[i],
            strand: widget.skill.strand,
          ),
          if (i != visibleCount - 1) const SizedBox(height: 8),
        ],
        if (!_expanded && remaining > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            key: const ValueKey('garden-evidence-see-more'),
            behavior: HitTestBehavior.opaque,
            onTap: withTapClick(() {
              setState(() => _expanded = true);
              widget.onExpanded?.call();
            }),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'See $remaining more ${remaining == 1 ? 'way' : 'ways'} you used this skill',
                      textAlign: TextAlign.center,
                      style: EllaFonts.body(
                        const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: EllaColors.berryDeep,
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: EllaColors.berryDeep,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidenceBox extends StatelessWidget {
  final GardenEvidence evidence;
  final Strand strand;
  const _EvidenceBox({super.key, required this.evidence, required this.strand});

  @override
  Widget build(BuildContext context) {
    final track = strand.track;
    final topic = _evidenceTopicLabel(evidence);
    final when = _relativeTime(evidence.createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ellaSmoothDecoration(
        color: track.surface,
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: track.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: SvgPicture.asset(
                  _quoteIconAsset,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(track.text, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  evidence.quote,
                  style: EllaFonts.body(
                    TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: track.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                topic,
                style: EllaFonts.body(
                  TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: track.text,
                  ),
                ),
              ),
              if (when != null) ...[
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: track.text,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  when,
                  style: EllaFonts.body(
                    TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: track.text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _evidenceTopicLabel(GardenEvidence evidence) {
  if (evidence.topic.isEmpty) {
    return evidence.prompted ? 'Ella asked' : 'On your own';
  }
  if (evidence.topic.toLowerCase().startsWith('talking about')) {
    return evidence.topic;
  }
  return 'Talking about ${evidence.topic}';
}

class _EmptySkillState extends StatelessWidget {
  const _EmptySkillState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(_tileAsset, width: 63, height: 48),
          const SizedBox(height: 16),
          Text(
            'This plant grows when you use this skill in your conversations',
            key: const ValueKey('garden-empty-skill-message'),
            textAlign: TextAlign.center,
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: _emptyPrompt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unit sheet body ────────────────────────────────────────────────────────

class _UnitSheetBody extends StatelessWidget {
  final GardenStep step;
  final bool isPreviousGarden;
  const _UnitSheetBody({required this.step, this.isPreviousGarden = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ResolvedSvgIcon(
                key: ValueKey('garden-unit-sheet-icon-${step.step}'),
                rawIcon: step.icon,
                fallbackAsset: _unitFallbackIcon,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.displayName,
                  key: const ValueKey('garden-unit-sheet-title'),
                  style: EllaFonts.bricolage(
                    const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.018,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "When this garden blooms, you'll be able to",
            key: const ValueKey('garden-unit-sheet-heading'),
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: _sectionTitle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final skill in step.skills) ...[
            _SkillRow(
              skill: skill,
              onTap: () {
                Navigator.of(context).pop();
                showSkillSheet(
                  context,
                  step,
                  skill,
                  isPreviousGarden: isPreviousGarden,
                );
              },
            ),
            if (skill != step.skills.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final GardenSkill skill;
  final VoidCallback onTap;
  const _SkillRow({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final track = skill.strand.track;
    return GestureDetector(
      key: ValueKey('garden-unit-skill-row-${skill.id}'),
      onTap: withTapClick(onTap),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: ellaSmoothDecoration(
          color: track.surface,
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: track.border, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResolvedSvgIcon(
              key: ValueKey('garden-unit-skill-icon-${skill.id}'),
              rawIcon: skill.icon,
              fallbackAsset: skill.strand.icon,
              size: 48,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    skill.displayText,
                    style: EllaFonts.body(
                      const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.128,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skill.strand.label,
                    style: EllaFonts.body(
                      TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.112,
                        color: track.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
