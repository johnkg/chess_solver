import 'opponent.dart';
import 'piece.dart';
import 'position.dart';

/// What you must achieve in a training position.
enum DrillGoal {
  /// Checkmate the engine before running out of moves.
  mate,

  /// Promote your pawn and keep the new piece.
  promote,

  /// You defend: draw (stalemate, win the pawn, or just survive) against an
  /// engine that is trying to win.
  hold,

  /// Mark every square (or file) that shows [Drill.concept] for [Drill.subject].
  find,
}

/// A position to play out against the engine. Generated data (see
/// tool/drills_data.py) is checked against the Python tablebase/engine.
class Drill {
  const Drill({
    required this.id,
    required this.phase,
    required this.title,
    required this.task,
    required this.fen,
    required this.side,
    required this.goal,
    required this.maxMoves,
    required this.hint,
    this.level = 'expert',
    this.lesson,
    this.answers = const [],
    this.explain = '',
    this.concept,
    this.subject = white,
  });

  final String id;

  /// 'opening', 'middlegame' or 'endgame'.
  final String phase;
  final String title;

  /// One sentence telling you what to do.
  final String task;
  final String fen;

  /// Colour you play: [white] or [black].
  final int side;
  final DrillGoal goal;

  /// How many of your own moves you get (for [DrillGoal.hold]: how many you
  /// must survive).
  final int maxMoves;
  final String hint;

  /// Name of the engine [Level] you play against.
  final String level;

  /// Id of the lesson that explains it, if any.
  final String? lesson;

  /// For [DrillGoal.find]: the correct answers (squares such as 'e6', or one
  /// square per file for file concepts) and a sentence that explains them.
  final List<String> answers;
  final String explain;

  /// For [DrillGoal.find]: the [Concept] name and whose structure to look at.
  final String? concept;
  final int subject;

  Level get engineLevel => Level.values.firstWhere((l) => l.name == level);
}

enum DrillState { running, success, failure }

class DrillStatus {
  const DrillStatus(this.state, [this.message = '']);

  final DrillState state;
  final String message;

  bool get over => state != DrillState.running;
}

int _count(Position pos, int color, bool Function(int type) test) {
  var n = 0;
  for (final p in pos.squares) {
    if (p != empty && pieceColor(p) == color && test(pieceType(p))) n++;
  }
  return n;
}

/// Where a drill stands in [pos] after [userMoves] of your moves. Call it
/// after each full move (yours and the reply) and when the game ends.
DrillStatus drillStatus(Drill drill, Position pos, int userMoves) {
  final me = drill.side;
  final foe = 1 - me;
  if (pos.isCheckmate) {
    return pos.turn == foe
        ? const DrillStatus(DrillState.success, 'Checkmate!')
        : const DrillStatus(DrillState.failure, 'You were checkmated.');
  }
  final myPawns = _count(pos, me, (t) => t == pawn);
  final myPieces = _count(pos, me, (t) => t != pawn && t != king);
  final foePawns = _count(pos, foe, (t) => t == pawn);
  final foePieces = _count(pos, foe, (t) => t != pawn && t != king);
  final stalemate = pos.isStalemate;
  final draw = drawReason(pos);

  switch (drill.goal) {
    case DrillGoal.mate:
      if (stalemate) {
        return const DrillStatus(DrillState.failure, 'Stalemate: no mate this time.');
      }
      if (draw != null) return DrillStatus(DrillState.failure, '$draw.');
      if (userMoves >= drill.maxMoves) {
        return DrillStatus(
          DrillState.failure,
          'Out of moves (${drill.maxMoves}).',
        );
      }
    case DrillGoal.promote:
      if (stalemate) {
        return const DrillStatus(DrillState.failure, 'Stalemate: a draw.');
      }
      if (myPawns == 0 && myPieces > 0 && pos.turn == me) {
        return const DrillStatus(
          DrillState.success,
          'Promoted, and the new piece is safe.',
        );
      }
      if (myPawns == 0 && myPieces == 0) {
        return const DrillStatus(
          DrillState.failure,
          'The pawn is lost: a draw.',
        );
      }
      if (userMoves >= drill.maxMoves) {
        return DrillStatus(
          DrillState.failure,
          'Out of moves (${drill.maxMoves}).',
        );
      }
    case DrillGoal.find:
      break;
    case DrillGoal.hold:
      if (stalemate) {
        return const DrillStatus(DrillState.success, 'Stalemate: you held the draw!');
      }
      if (foePawns == 0 && foePieces == 0) {
        return const DrillStatus(
          DrillState.success,
          'The pawn is gone: a draw.',
        );
      }
      if (foePawns == 0 && foePieces > 0 && pos.turn == me) {
        return const DrillStatus(DrillState.failure, 'The pawn promoted.');
      }
      if (draw != null) {
        return DrillStatus(DrillState.success, '$draw: you held.');
      }
      if (userMoves >= drill.maxMoves) {
        return DrillStatus(
          DrillState.success,
          'You held for ${drill.maxMoves} moves: the draw stands.',
        );
      }
  }
  return const DrillStatus(DrillState.running);
}
