import 'dart:math';

import 'piece.dart';
import 'position.dart';
import 'search.dart';

/// Plies searched (plus captures) to score each position of a game. Deep
/// enough to see simple tactics, fast enough for a whole game in the browser.
const int gameEvalDepth = 2;

/// Centipawns at which the eval bar is about three-quarters one colour: the
/// logistic scale of [whiteShare].
const double _shareScale = 400;

/// Score of [pos] from White's point of view, centipawns. A side that is
/// mated scores -[mateScore] for that side; see [isMateScore] for mates still
/// to come. Stalemate is 0.
int whiteScore(Position pos, {int depth = gameEvalDepth}) {
  final best = bestMove(pos, depth);
  final forMover = best?.score ?? (pos.inCheck ? -mateScore : 0);
  return pos.turn == white ? forMover : -forMover;
}

/// Moves (of the winning side) until mate for a mate score, else null.
/// 0 means the position is already checkmate.
int? movesToMate(int score) {
  if (!isMateScore(score)) return null;
  final plies = mateScore - score.abs();
  return (plies + 1) ~/ 2;
}

/// Short label for a White-view score: "+1.4", "-0.3", "0.0", "M2" (White
/// mates in 2), "-M2" (Black mates), "#" or "-#" for a finished mate.
String scoreLabel(int score) {
  final mate = movesToMate(score);
  final sign = score < 0 ? '-' : '';
  if (mate != null) return mate == 0 ? '$sign#' : '${sign}M$mate';
  final pawns = score / 100;
  if (pawns.abs() < 0.05) return '0.0';
  return '${pawns > 0 ? '+' : ''}${pawns.toStringAsFixed(1)}';
}

/// White's share of the eval bar, 0 (Black winning) to 1 (White winning).
double whiteShare(int score) {
  if (isMateScore(score)) return score > 0 ? 1 : 0;
  return 1 / (1 + pow(10, -score / _shareScale));
}

/// Moves that swung the game most. [scores] holds one White-view score per
/// position of the game (position i is before move i); [firstMover] is the
/// side to move in position 0. Returns the indexes of the moves that cost
/// their side at least [minLoss] centipawns, biggest loss first. Scores are
/// capped at [swingCap], so a missed mate counts as a large loss, not a huge one.
List<int> biggestSwings(List<int> scores, int firstMover, {int minLoss = 150}) {
  int capped(int s) => s.clamp(-swingCap, swingCap);
  final losses = <(int, int)>[];
  for (var i = 0; i + 1 < scores.length; i++) {
    final mover = i.isEven ? firstMover : 1 - firstMover;
    final change = capped(scores[i + 1]) - capped(scores[i]);
    final loss = mover == white ? -change : change;
    if (loss >= minLoss) losses.add((i, loss));
  }
  losses.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final l in losses) l.$1];
}

/// Centipawns a score is capped at when measuring swings.
const int swingCap = 1500;
