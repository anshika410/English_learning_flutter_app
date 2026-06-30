// Garden detail dialogs — parchment cards opened by tapping a plant or a unit.
//   • showSkillSheet  — a single skill: evidence ("What You Said") or empty state.
//   • showUnitSheet   — a step/unit: focus + the skills you'll master.
// Styled to the Figma "Skill Sheet" / "Unit Sheet" screens.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme_colors.dart';
import '../../../models/garden.dart';

const Color _parchment = Color(0xFFFBF4E4);
const Color _parchmentLine = Color(0xFFE7D7B6);
const Color _badgeBrown = Color(0xFF8A5A2B);
const Color _ink = Color(0xFF4A3621);

void showSkillSheet(BuildContext context, GardenStep step, GardenSkill skill) {
  _showParchment(
    context,
    badge: step.name,
    child: _SkillSheetBody(skill: skill),
  );
}

void showUnitSheet(BuildContext context, GardenData data, GardenStep step) {
  _showParchment(
    context,
    badge: step.name,
    child: _UnitSheetBody(data: data, step: step),
  );
}

// ── Shared parchment shell with the brown badge overlapping the top edge ──────

void _showParchment(
  BuildContext context, {
  required String badge,
  required Widget child,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                decoration: BoxDecoration(
                  color: _parchment,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _parchmentLine, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(child: child),
              ),
              // Brown step badge straddling the top border.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _badgeBrown,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Skill sheet body ─────────────────────────────────────────────────────────

class _SkillSheetBody extends StatelessWidget {
  final GardenSkill skill;
  const _SkillSheetBody({required this.skill});

  @override
  Widget build(BuildContext context) {
    final hasEvidence = skill.evidence.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(skill.strand.icon, width: 34, height: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.text,
                style: GoogleFonts.baloo2(
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(label: skill.strand.label, bg: skill.strand.tagBg, fg: skill.strand.tagColor),
            _Tag(
              label: skill.status.tag,
              bg: EllaColors.mangoLightest,
              fg: EllaColors.mangoDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: _parchmentLine, height: 1),
        const SizedBox(height: 14),
        if (hasEvidence) ...[
          Row(
            children: [
              SvgPicture.asset('assets/information-box/talk-svgrepo-com.svg',
                  width: 16, height: 16),
              const SizedBox(width: 6),
              Text(
                'WHAT YOU SAID',
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: EllaColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in skill.evidence) ...[
            _EvidenceBox(evidence: e),
            const SizedBox(height: 8),
          ],
        ] else
          _EmptyState(strand: skill.strand),
      ],
    );
  }
}

class _EvidenceBox extends StatelessWidget {
  final GardenEvidence evidence;
  const _EvidenceBox({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final pct = (evidence.confidence * 100).round();
    final sub = evidence.prompted ? 'Zoe asked' : 'You said it on your own';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _parchmentLine, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '"${evidence.quote}"',
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$sub  •  $pct% match',
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: EllaColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Strand strand;
  const _EmptyState({required this.strand});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset('assets/information-box/clock.svg', width: 40, height: 40),
        const SizedBox(height: 10),
        Text(
          'Waiting to be planted!',
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Talk to Zoe to start growing this skill.',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: EllaColors.muted,
          ),
        ),
      ],
    );
  }
}

// ── Unit sheet body ────────────────────────────────────────────────────────--

class _UnitSheetBody extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  const _UnitSheetBody({required this.data, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'UNIT ${step.step} OF ${data.steps.length}',
          style: GoogleFonts.baloo2(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: EllaColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step.focus,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: _ink,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: _parchmentLine, height: 1),
        const SizedBox(height: 14),
        Text(
          'ON MASTERY, YOU WILL BE ABLE TO',
          style: GoogleFonts.baloo2(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: EllaColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        for (final skill in step.skills) ...[
          _SkillRow(
            skill: skill,
            onTap: () {
              Navigator.of(context).pop();
              showSkillSheet(context, step, skill);
            },
          ),
          const SizedBox(height: 10),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _parchmentLine, width: 1),
        ),
        child: Row(
          children: [
            SvgPicture.asset(skill.strand.icon, width: 30, height: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    skill.text,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skill.strand.label,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: skill.strand.tagColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: EllaColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Tag({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: GoogleFonts.baloo2(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
