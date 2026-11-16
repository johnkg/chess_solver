import 'dart:math';

import 'opponent.dart';

/// Rating a new player starts from.
const int startRating = 1000;

/// Chance (0..1) that a player rated [mine] scores against [theirs].
double expectedScore(int mine, int theirs) =>
    1 / (1 + pow(10, (theirs - mine) / 400));

/// The Elo update. [score] is 1 for a win, 0.5 for a draw, 0 for a loss;
/// [games] is how many rated games came before (the first ten move faster).
int updatedRating(int mine, int theirs, double score, {required int games}) {
  final k = games < 10 ? 40 : 24;
  return (mine + k * (score - expectedScore(mine, theirs))).round();
}

/// The level whose target rating is nearest to [rating]; the weaker one when
/// two are equally near.
Level levelForRating(int rating) {
  var nearest = Level.values.first;
  for (final level in Level.values) {
    if ((level.elo - rating).abs() < (nearest.elo - rating).abs()) nearest = level;
  }
  return nearest;
}

/// Puzzle rating of each difficulty tier (index 0 = tier 1). A puzzle you
/// solve cleanly counts as a win against this rating, a miss as a loss.
const List<int> tierRatings = [800, 1000, 1200, 1400, 1600];

/// The rating of a puzzle of difficulty [tier] (1 to 5).
int tierRating(int tier) => tierRatings[(tier - 1).clamp(0, tierRatings.length - 1)];

/// One finished, rated game against the engine.
class GameRecord {
  const GameRecord({
    required this.opponentElo,
    required this.score,
    required this.ratingAfter,
  });

  /// The level's target rating.
  final int opponentElo;

  /// 1, 0.5 or 0.
  final double score;
  final int ratingAfter;

  String get result => score == 1 ? 'W' : (score == 0 ? 'L' : 'D');

  String encode() => '$opponentElo,$score,$ratingAfter';

  static GameRecord? decode(String text) {
    final p = text.split(',');
    if (p.length != 3) return null;
    final elo = int.tryParse(p[0]);
    final score = double.tryParse(p[1]);
    final after = int.tryParse(p[2]);
    if (elo == null || score == null || after == null) return null;
    return GameRecord(opponentElo: elo, score: score, ratingAfter: after);
  }
}
