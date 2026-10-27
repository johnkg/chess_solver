import 'dart:math';

import 'puzzle.dart';
import 'review.dart';

/// Keys with a positive miss count that some puzzle can drill, worst first.
List<MapEntry<String, int>> weakest(
  Map<String, int> missed,
  List<Puzzle> library, {
  int n = 3,
}) {
  final drillable = {for (final p in library) weakKey(p.idea)};
  final list = [
    for (final e in missed.entries)
      if (e.value > 0 && drillable.contains(e.key)) e,
  ]..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list.take(n).toList();
}

/// The next puzzle for the worst weak spot: an unsolved one (easiest tier
/// first) if any, otherwise a random solved one. Puzzles in [seen] (this
/// drill so far) and [skipId] are left out, so a drill walks through every
/// weak spot's puzzles before it repeats one. Null when nothing is drillable.
Puzzle? nextWeakPuzzle(
  List<Puzzle> library,
  Map<String, int> missed,
  Set<String> solved, {
  String? skipId,
  Set<String> seen = const {},
  Random? random,
}) {
  Puzzle? pick(Set<String> avoid) {
    for (final spot in weakest(missed, library, n: 1000)) {
      final pool = [
        for (final p in library)
          if (weakKey(p.idea) == spot.key && p.id != skipId && !avoid.contains(p.id)) p,
      ];
      if (pool.isEmpty) continue;
      final unsolved = pool.where((p) => !solved.contains(p.id)).toList()
        ..sort((a, b) => a.tier.compareTo(b.tier));
      if (unsolved.isNotEmpty) return unsolved.first;
      return pool[(random ?? Random()).nextInt(pool.length)];
    }
    return null;
  }

  return pick(seen) ?? pick(const {});
}
