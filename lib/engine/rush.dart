import 'dart:math';

import 'puzzle.dart';

/// Puzzle Rush: as many puzzles as you can in [rushSeconds], three strikes
/// and you are out. They get harder as you go.
const int rushSeconds = 180;
const int rushStrikes = 3;

/// Puzzles that fit the rush format: one move wins (a material win or a
/// mate in 1).
List<Puzzle> rushPool(List<Puzzle> library) =>
    [for (final p in library) if (p.mateIn <= 1) p];

/// Difficulty tier wanted after [solved] correct answers: tier 1 first, one
/// tier harder every three solved.
int rushTier(int solved) => 1 + solved ~/ 3;

/// The next rush puzzle: an unseen one from the wanted tier, else the nearest
/// tier that has one; once everything was seen, any puzzle of the wanted tier.
Puzzle? nextRushPuzzle(
  List<Puzzle> pool,
  int solved,
  Set<String> seen, {
  Random? random,
}) {
  if (pool.isEmpty) return null;
  final rng = random ?? Random();
  final want = rushTier(solved);
  Puzzle? pick(List<Puzzle> from) => from.isEmpty ? null : from[rng.nextInt(from.length)];

  final fresh = [for (final p in pool) if (!seen.contains(p.id)) p];
  final candidates = fresh.isEmpty ? pool : fresh;
  final tiers = {for (final p in candidates) p.tier}.toList()
    ..sort((a, b) => (a - want).abs().compareTo((b - want).abs()) != 0
        ? (a - want).abs().compareTo((b - want).abs())
        : a.compareTo(b));
  return pick([for (final p in candidates) if (p.tier == tiers.first) p]);
}

/// The easiest unsolved puzzle at or above the tier you have mastered,
/// optionally limited to [only] (a theme). "Mastered" means every puzzle of
/// the tier is solved. Null when all are solved.
Puzzle? nextPathPuzzle(
  List<Puzzle> library,
  Set<String> solved, {
  bool Function(Puzzle)? only,
}) {
  final pool = [for (final p in library) if (only == null || only(p)) p];
  final open = [for (final p in pool) if (!solved.contains(p.id)) p]
    ..sort((a, b) {
      final c = a.tier.compareTo(b.tier);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return open.isEmpty ? null : open.first;
}
