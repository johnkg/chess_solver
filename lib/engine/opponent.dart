import 'dart:math';

import 'mistakes.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'search.dart';

/// How strong the computer opponent plays.
enum Level {
  beginner(1, 200),
  casual(2, 60),
  club(3, 10);

  const Level(this.depth, this.slack);

  /// Plies searched.
  final int depth;

  /// The engine may pick any move scoring within this many centipawns of the
  /// best one, so weaker levels make human-sized mistakes (and no level plays
  /// the exact same game every time).
  final int slack;

  String get label => switch (this) {
        Level.beginner => 'Beginner',
        Level.casual => 'Casual',
        Level.club => 'Club',
      };
}

/// In the first moves many replies are about equally good, so every level
/// varies its opening instead of always playing the same line.
const int _openingSlack = 40;
const int _openingMoves = 8;

/// The opponent's reply in [pos], or null if there is no legal move. A forced
/// mate is always played when found.
Move? chooseMove(Position pos, Level level, [Random? random]) {
  final mate = findMate(pos, 2);
  if (mate != null) return mate.move;
  final scored = scoreMoves(pos, level.depth);
  if (scored.isEmpty) return null;
  final best = scored.map((e) => e.$2).reduce(max);
  final slack = isMateScore(best)
      ? 0
      : max(level.slack, pos.fullmove <= _openingMoves ? _openingSlack : 0);
  final pool = [
    for (final e in scored)
      if (e.$2 >= best - slack) e.$1,
  ];
  return pool[(random ?? Random()).nextInt(pool.length)];
}

/// Why the game is drawn (other than stalemate), or null.
String? drawReason(Position pos) {
  if (pos.halfmove >= 100) return 'Draw by the fifty-move rule';
  var minors = 0;
  for (final p in pos.squares) {
    if (p == empty) continue;
    switch (pieceType(p)) {
      case king:
        break;
      case knight || bishop:
        minors++;
      default:
        return null;
    }
  }
  return minors <= 1 ? 'Draw: not enough pieces to checkmate' : null;
}
