// Garden detail dialogs — Figma-styled cards opened by tapping a plant or unit.

import 'dart:math' as math;

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
const Color _woodText = Color(0xCCFFFFFF);
const Color _woodNail = Color(0xFF3A2010);
const Color _sectionTitle = Color(0xFF8C725B);
const Color _emptyPrompt = Color(0xFF7A4400);

const String _tileAsset = 'assets/gardent-view/tiles.svg';
const String _talkIconAsset = 'assets/information-box/talk-svgrepo-com.svg';
const String _quoteIconAsset = 'assets/information-box/quote-mark.svg';
const String _unitFallbackIcon = 'assets/information-box/unit-globe.svg';

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

void showSkillSheet(
  BuildContext context,
  GardenStep step,
  GardenSkill skill, {
  bool isPreviousGarden = false,
}) {
  _showGardenSheet(
    context,
    boardTitle: step.displayName,
    child: _SkillSheetBody(skill: skill, isPreviousGarden: isPreviousGarden),
  );
}

void showUnitSheet(
  BuildContext context,
  GardenData data,
  GardenStep step, {
  bool isPreviousGarden = false,
}) {
  _showGardenSheet(
    context,
    boardTitle: step.displayName,
    child: _UnitSheetBody(
      data: data,
      step: step,
      isPreviousGarden: isPreviousGarden,
    ),
  );
}

// ── Shared Figma card shell ─────────────────────────────────────────────────

void _showGardenSheet(
  BuildContext context, {
  required String boardTitle,
  required Widget child,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final mediaSize = MediaQuery.sizeOf(ctx);
      final maxSheetHeight = mediaSize.height * 0.78;
      final sheetWidth = math.min(430.0, mediaSize.width - 48);
      final boardWidth = _sheetBoardWidthFor(boardTitle, sheetWidth);
      final boardHeight = _sheetBoardHeightFor(boardTitle);
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      key: const ValueKey('garden-sheet-card'),
                      width: double.infinity,
                      constraints: BoxConstraints(maxHeight: maxSheetHeight),
                      margin: EdgeInsets.only(top: boardHeight / 2),
                      padding: EdgeInsets.fromLTRB(16, boardHeight + 8, 16, 24),
                      clipBehavior: Clip.antiAlias,
                      decoration: ellaSmoothDecoration(
                        color: _sheetSurface,
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: _sheetBorder),
                      ),
                      child: SingleChildScrollView(child: child),
                    ),
                    _SheetBoard(
                      title: boardTitle,
                      width: boardWidth,
                      height: boardHeight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

int _titleWordCount(String title) =>
    title.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

double _sheetBoardWidthFor(String title, double sheetWidth) {
  final maxWidth = math.max(0.0, sheetWidth);
  final words = _titleWordCount(title);
  if (words <= 2) return math.min(268.0, maxWidth);
  if (words <= 3) return math.min(334.0, maxWidth);
  return math.min(358.0, maxWidth);
}

double _sheetBoardHeightFor(String title) =>
    _titleWordCount(title) <= 3 ? 48.0 : 64.0;

class _SheetBoard extends StatelessWidget {
  final String title;
  final double width;
  final double height;
  const _SheetBoard({
    required this.title,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-sheet-board'),
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
      child: Row(
        children: [
          const _NailDot(),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              maxLines: height > 48 ? 2 : 1,
              textAlign: TextAlign.center,
              style: EllaFonts.body(
                const TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: _woodText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const _NailDot(),
        ],
      ),
    );
  }
}

class _NailDot extends StatelessWidget {
  const _NailDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
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

  /// Previous (completed) gardens have no sessions to start, so a skill
  /// without evidence ends at the chips — no divider, no tile icon, no
  /// "Talk with Zoe" prompt. Evidence, when present, is always shown.
  final bool isPreviousGarden;
  const _SkillSheetBody({required this.skill, this.isPreviousGarden = false});

  @override
  Widget build(BuildContext context) {
    final evidence = skill.evidence.take(3).toList();
    return Column(
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
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StrandChip(strand: skill.strand),
            ),
            _GrowthStateChip(skill: skill),
          ],
        ),
        if (evidence.isNotEmpty || !isPreviousGarden) ...[
          const SizedBox(height: 16),
          const _WoodDivider(),
          const SizedBox(height: 20),
          if (evidence.isEmpty)
            const _EmptySkillState()
          else
            _EvidenceSection(skill: skill, evidence: evidence),
        ],
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
      child: Center(
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

class _GrowthVisual {
  final String key;
  final String label;
  final String asset;
  final Color bg;
  final Color fg;

  const _GrowthVisual({
    required this.key,
    required this.label,
    required this.asset,
    required this.bg,
    required this.fg,
  });
}

const _seedGrowth = _GrowthVisual(
  key: 'seed',
  label: 'Seed',
  asset: 'assets/information-box/growth-seed.svg',
  bg: Color(0xFFE6D3C3),
  fg: Color(0xFF9A6A44),
);

const _sproutGrowth = _GrowthVisual(
  key: 'sprout',
  label: 'Sprout',
  asset: 'assets/information-box/growth-sprout.svg',
  bg: EllaColors.fieldLight,
  fg: EllaColors.fieldDark,
);

const _buddingGrowth = _GrowthVisual(
  key: 'budding',
  label: 'Budding',
  asset: 'assets/information-box/growth-budding.svg',
  bg: EllaColors.greenLight,
  fg: EllaColors.greenDeep,
);

const _bloomGrowth = _GrowthVisual(
  key: 'bloomed',
  label: 'Bloomed',
  asset: 'assets/information-box/growth-bloom.svg',
  bg: EllaColors.berryLight,
  fg: EllaColors.berryDeep,
);

_GrowthVisual _growthVisualFor(GardenSkill skill) {
  if (skill.status == SkillStatus.owned || skill.sightings >= 3) {
    return _bloomGrowth;
  }
  if (skill.sightings == 2) return _buddingGrowth;
  if (skill.sightings == 1) return _sproutGrowth;
  return _seedGrowth;
}

class _GrowthStateChip extends StatelessWidget {
  final GardenSkill skill;
  const _GrowthStateChip({required this.skill});

  @override
  Widget build(BuildContext context) {
    final visual = _growthVisualFor(skill);
    return Container(
      key: ValueKey('garden-growth-state-${visual.key}'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: visual.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(visual.asset, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(
            visual.label,
            style: EllaFonts.body(
              TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.048,
                color: visual.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  final GardenSkill skill;
  final List<GardenEvidence> evidence;
  const _EvidenceSection({required this.skill, required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SvgPicture.asset(_talkIconAsset, width: 32, height: 32),
            const SizedBox(width: 12),
            Text(
              'You Said',
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
        for (var i = 0; i < evidence.length; i++) ...[
          _EvidenceBox(
            key: ValueKey('garden-evidence-card-$i'),
            evidence: evidence[i],
            strand: skill.strand,
          ),
          if (i != evidence.length - 1) const SizedBox(height: 8),
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
            'Talk with Ella to grow this skill.',
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

class _UnitSheetBody extends StatefulWidget {
  final GardenData data;
  final GardenStep step;
  final bool isPreviousGarden;
  const _UnitSheetBody({
    required this.data,
    required this.step,
    this.isPreviousGarden = false,
  });

  @override
  State<_UnitSheetBody> createState() => _UnitSheetBodyState();
}

class _UnitSheetBodyState extends State<_UnitSheetBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final visibleSkills = _expanded ? step.skills : step.skills.take(2);
    final hasMore = step.skills.length > 2 && !_expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "When this blooms, you'll be able to",
          style: EllaFonts.body(
            const TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: _sectionTitle,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final skill in visibleSkills) ...[
          _SkillRow(
            skill: skill,
            onTap: () {
              Navigator.of(context).pop();
              showSkillSheet(
                context,
                step,
                skill,
                isPreviousGarden: widget.isPreviousGarden,
              );
            },
          ),
          if (skill != visibleSkills.last) const SizedBox(height: 16),
        ],
        if (hasMore) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const ValueKey('garden-unit-show-more'),
              onPressed: withTapClick(() => setState(() => _expanded = true)),
              style: TextButton.styleFrom(
                foregroundColor: EllaColors.soil,
                textStyle: EllaFonts.body(
                  const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              label: const Text('Show more'),
            ),
          ),
        ],
      ],
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
