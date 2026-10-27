import 'dart:math';

import 'book.dart';
import 'engine.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'search.dart';

/// How strong the computer opponent plays. The ratings are targets for how
/// each level is tuned (search depth, thinking time, how often it plays a
/// near-best move instead of the best one); they are not measured Elo.
enum Level {
  beginner('Beginner', 600, depth: 1, millis: 150, temperature: 150, margin: 350, bookPlies: 2, mateDepth: 1),
  casual('Casual', 1000, depth: 2, millis: 250, temperature: 70, margin: 200, bookPlies: 6, mateDepth: 1),
  club('Club', 1400, depth: 3, millis: 500, temperature: 35, margin: 120, bookPlies: 10, mateDepth: 2),
  expert('Expert', 1800, depth: 4, millis: 1000, temperature: 18, margin: 70, bookPlies: 14),
  master('Master', 2200, depth: 6, millis: 2500, temperature: 8, margin: 40, bookPlies: 20),
  grandmaster('Grandmaster', 2500, depth: 9, millis: 5000, temperature: 3, margin: 25, bookPlies: 24);

  const Level(
    this.label,
    this.elo, {
    required this.depth,
    required this.millis,
    required this.temperature,
    required this.margin,
    required this.bookPlies,
    this.mateDepth = 0,
  });

  final String label;

  /// Target playing strength (see the note above).
  final int elo;

  /// Deepest search in plies.
  final int depth;

  /// Thinking time per move, milliseconds.
  final int millis;

  /// Among moves close to the best, the chance of choosing one falls off by
  /// a factor of e for every [temperature] centipawns it is worse. Low
  /// temperature = nearly always the best move.
  final int temperature;

  /// Moves further than this from the best are never played.
  final int margin;

  /// The opening book is used for this many half-moves.
  final int bookPlies;

  /// Plain forced-mate search before thinking (the weakest levels only see
  /// mate in 1). Zero means the normal search finds mates by itself.
  final int mateDepth;

  String get title => '$label · about $elo';
}

/// The opponent's reply in [pos], or null if there is no legal move.
///
/// It plays an opening line from its book (a different one each game), and
/// afterwards searches for the best moves. Rather than always playing the
/// single best move it picks among the near-best ones, weighted by how good
/// they are, so games differ but every move still has a reason. A forced
/// mate is always played when found. [maxMillis] overrides the level's
/// thinking time (tests use it).
Move? chooseMove(Position pos, Level level, [Random? random, int? maxMillis]) {
  final rng = random ?? Random();
  final legal = pos.legalMoves();
  if (legal.isEmpty) return null;
  if (legal.length == 1) return legal.first;

  if (level.mateDepth > 0) {
    final mate = findMate(pos, level.mateDepth);
    if (mate != null) return mate.move;
  }
  final booked = bookMove(pos, level.bookPlies, rng);
  if (booked != null) return booked;

  final result = Searcher().search(
    pos,
    maxDepth: level.depth,
    millis: maxMillis ?? level.millis,
    margin: level.margin,
  )!;
  final best = result.best.$2;
  if (isMateScore(best)) return result.best.$1;
  final weights = [
    for (final e in result.moves) exp(-(best - e.$2) / level.temperature),
  ];
  var pick = rng.nextDouble() * weights.reduce((a, b) => a + b);
  for (var i = 0; i < weights.length; i++) {
    pick -= weights[i];
    if (pick <= 0) return result.moves[i].$1;
  }
  return result.best.$1;
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
