import 'dart:math';

import 'puzzle.dart';
import 'rating.dart';

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

/// The unsolved puzzle whose tier rating is nearest [rating], optionally
/// limited to [only]; ties go to the easier tier, then by id. Null when all
/// are solved.
Puzzle? nextRatedPuzzle(
  List<Puzzle> library,
  Set<String> solved,
  int rating, {
  bool Function(Puzzle)? only,
}) {
  Puzzle? best;
  int distance(Puzzle p) => (tierRating(p.tier) - rating).abs();
  for (final p in library) {
    if (solved.contains(p.id) || (only != null && !only(p))) continue;
    final b = best;
    if (b == null) {
      best = p;
      continue;
    }
    final c = distance(p).compareTo(distance(b));
    if (c < 0 || (c == 0 && (p.tier < b.tier || (p.tier == b.tier && p.id.compareTo(b.id) < 0)))) best = p;
  }
  return best;
}
