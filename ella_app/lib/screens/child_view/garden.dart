// Garden widget — the child-facing progress metaphor.
// Shows the current active unit step's skills as emoji plants.
// locked = 🌱 faded, emerging = 🌿 normal, owned = 🌳 bright.
// After endChat(), lastChanges drives the "grew!" highlight animation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engine.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';

class Garden extends ConsumerWidget {
  const Garden({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _GardenContent(state: s),
      loading: () => const SizedBox(height: 80),
      error: (_, _) => const SizedBox(height: 80),
    );
  }
}

class _GardenContent extends StatelessWidget {
  final ChatState state;
  const _GardenContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final mem = state.memory;
    final step = activeStep(mem);
    final changedIds = state.lastChanges.map((c) => c.id).toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Effort count + level
          Row(
            children: [
              const Text('🌟', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${mem.effortTimesSpoken} times spoken  •  ${mem.level}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (step != null) ...[
            const SizedBox(height: 6),
            Text(
              step.name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            // Plant row for this step
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: step.skills.map((s) {
                final bucket = bucketOf(mem, s.id);
                final grew = changedIds.contains(s.id);
                return _Plant(skillId: s.id, bucket: bucket, grew: grew);
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '🌳 All units complete!',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

class _Plant extends StatefulWidget {
  final String skillId;
  final String bucket;
  final bool grew;

  const _Plant({required this.skillId, required this.bucket, required this.grew});

  @override
  State<_Plant> createState() => _PlantState();
}

class _PlantState extends State<_Plant> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    if (widget.grew) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = switch (widget.bucket) {
      'owned' => '🌳',
      'emerging' => '🌿',
      _ => '🌱',
    };
    final opacity = widget.bucket == 'locked' ? 0.45 : 1.0;

    return ScaleTransition(
      scale: _scale,
      child: Opacity(
        opacity: opacity,
        child: Text(emoji, style: const TextStyle(fontSize: 36)),
      ),
    );
  }
}

// "Grew!" overlay shown briefly after endChat when skills advanced.
class GrewBanner extends StatelessWidget {
  final List<StateChange> changes;
  const GrewBanner({super.key, required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    final toOwned = changes.where((c) => c.to == 'owned').length;
    final toEmerging = changes.where((c) => c.to == 'emerging').length;
    final parts = [
      if (toOwned > 0) '$toOwned skill${toOwned > 1 ? 's' : ''} owned! 🌳',
      if (toEmerging > 0) '$toEmerging emerging 🌿',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉 ', style: TextStyle(fontSize: 18)),
          Text(
            parts.join('  '),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
