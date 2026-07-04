// Unit tests for the garden derivation helpers (gardenStateOf / gardenTally).
// These power the non-linear garden map's 4-state tiles and the top meter.
// Run with: flutter test test/core/garden_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/core/engine.dart';
import 'package:ella_app/core/skill_data.dart';
import 'package:ella_app/models/child_memory.dart';

void main() {
  const id = 'U1-VOC-01';

  group('gardenStateOf', () {
    test('locked / no evidence → 0 (empty)', () {
      final mem = MemoryState.fresh('A1');
      expect(gardenStateOf(mem, id), 0);
    });

    test('emerging with no spontaneous use → 1 (emerging)', () {
      final mem = MemoryState.fresh('A1').copyWith(emerging: [id]);
      expect(gardenStateOf(mem, id), 1);
    });

    test('emerging with strength >= 1 → 2 (growing)', () {
      final mem = MemoryState.fresh('A1').copyWith(
        emerging: [id],
        strength: {id: 1},
      );
      expect(gardenStateOf(mem, id), 2);
    });

    test('owned → 3 regardless of strength', () {
      final mem = MemoryState.fresh('A1').copyWith(owned: [id]);
      expect(gardenStateOf(mem, id), 3);
    });
  });

  group('gardenTally', () {
    test('fresh memory: nothing owned or sprouting, total = all unit skills', () {
      final mem = MemoryState.fresh('A1');
      final expectedTotal =
          kUnitSteps.fold<int>(0, (sum, u) => sum + u.skills.length);
      final t = gardenTally(mem);
      expect(t.owned, 0);
      expect(t.sprouting, 0);
      expect(t.total, expectedTotal);
    });

    test('counts owned (state 3) and sprouting (state 1 or 2) separately', () {
      final mem = MemoryState.fresh('A1').copyWith(
        owned: ['U1-VOC-01', 'U1-GRA-01'], // 2 owned
        emerging: ['U2-VOC-01', 'U2-GRA-01'], // 2 sprouting (one growing)
        strength: {'U2-GRA-01': 2},
      );
      final t = gardenTally(mem);
      expect(t.owned, 2);
      expect(t.sprouting, 2);
    });
  });
}
