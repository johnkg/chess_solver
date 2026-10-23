import 'eval.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';

/// Score of a checkmate. A mate `ply` plies away scores `mateScore - ply`.
const int mateScore = 100000;

/// True if a score means "forced mate found".
bool isMateScore(int score) => score.abs() > mateScore - 1000;

bool _isCapture(Position pos, Move m) =>
    pos.squares[m.to] != empty || m.flag == Move.enPassant;

// ---------------------------------------------------------------------------
// Mate in N
// ---------------------------------------------------------------------------

/// A move that forces checkmate within [n] of the mover's own moves, or
/// `null` if there is none. Stalemate is not mate.
///
/// Exhaustive AND/OR search: the mover needs one move such that every reply
/// still leads to mate. Fine for small [n] (1 to 3).
Move? mateIn(Position pos, int n) {
  final withCheck = <(Move, Position)>[];
  final withoutCheck = <(Move, Position)>[];
  for (final m in pos.legalMoves()) {
    final next = pos.makeMove(m);
    (next.inCheck ? withCheck : withoutCheck).add((m, next));
  }

  // Checking moves first: they are the most likely mates.
  for (final (m, next) in [...withCheck, ...withoutCheck]) {
    final replies = next.legalMoves();
    if (replies.isEmpty) {
      if (next.inCheck) return m;
      continue; // stalemate
    }
    if (n > 1 &&
        replies.every((r) => mateIn(next.makeMove(r), n - 1) != null)) {
      return m;
    }
  }
  return null;
}

/// Shortest forced mate up to [maxMoves] moves, or `null`.
({int moves, Move move})? findMate(Position pos, int maxMoves) {
  for (var n = 1; n <= maxMoves; n++) {
    final m = mateIn(pos, n);
    if (m != null) return (moves: n, move: m);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Alpha-beta
// ---------------------------------------------------------------------------

/// Captures first, most valuable victim by least valuable attacker, then
/// promotions. Stable: equal moves keep generation order.
List<Move> orderMoves(Position pos, List<Move> moves) {
  int key(Move m) {
    final victim = pos.squares[m.to];
    final int cap;
    if (victim != empty) {
      final attacker = pieceType(pos.squares[m.from]);
      cap = pieceValue(pieceType(victim)) * 1000 - pieceValue(attacker) * 100;
    } else {
      cap = m.flag == Move.enPassant ? 900 : 0;
    }
    return -(cap + (m.promotion != 0 ? 800 : 0));
  }

  final scored = [
    for (var i = 0; i < moves.length; i++) (key(moves[i]), i, moves[i]),
  ];
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final s in scored) s.$3];
}

int _quiesce(
  Position pos,
  int alpha,
  int beta,
  int ply,
  int Function(Position) ev,
) {
  final stand = ev(pos);
  if (stand >= beta) return stand;
  if (stand > alpha) alpha = stand;

  final tactical = [
    for (final m in pos.pseudoLegalMoves())
      if (_isCapture(pos, m) || m.promotion != 0) m,
  ];
  for (final m in orderMoves(pos, tactical)) {
    final next = pos.makeMove(m);
    final k = next.kingSquare(pos.turn);
    if (k >= 0 && next.isAttacked(k, 1 - pos.turn)) continue; // illegal
    final score = -_quiesce(next, -beta, -alpha, ply + 1, ev);
    if (score >= beta) return score;
    if (score > alpha) alpha = score;
  }
  return alpha;
}

/// Negamax with alpha-beta pruning. Score is from the side to move's view.
/// With [quiescence] false, leaves use the static eval directly. [evalFn]
/// replaces [evaluate] (for example [materialEval]).
int negamax(
  Position pos,
  int depth,
  int alpha,
  int beta,
  int ply, {
  bool quiescence = true,
  int Function(Position)? evalFn,
}) {
  final ev = evalFn ?? evaluate;
  final moves = pos.legalMoves();
  if (moves.isEmpty) return pos.inCheck ? -mateScore + ply : 0;
  if (depth == 0) {
    return quiescence ? _quiesce(pos, alpha, beta, ply, ev) : ev(pos);
  }

  var best = -mateScore - 1;
  for (final m in orderMoves(pos, moves)) {
    final score = -negamax(
      pos.makeMove(m),
      depth - 1,
      -beta,
      -alpha,
      ply + 1,
      quiescence: quiescence,
      evalFn: evalFn,
    );
    if (score > best) best = score;
    if (score > alpha) alpha = score;
    if (alpha >= beta) break;
  }
  return best;
}

/// Best move at [depth] plies, or `null` if the side to move has no legal
/// move. `score` is centipawns for the side to move; see [isMateScore].
({Move move, int score})? bestMove(Position pos, int depth) {
  Move? best;
  var bestScore = -mateScore - 1;
  var alpha = -mateScore - 1;
  for (final m in orderMoves(pos, pos.legalMoves())) {
    final score =
        -negamax(pos.makeMove(m), depth - 1, -mateScore - 1, -alpha, 1);
    if (score > bestScore) {
      best = m;
      bestScore = score;
    }
    if (score > alpha) alpha = score;
  }
  return best == null ? null : (move: best, score: bestScore);
}

// ---------------------------------------------------------------------------
// Material-only checks, used to confirm tactical claims
// ---------------------------------------------------------------------------

/// Material balance from the side to move's point of view, centipawns.
int materialEval(Position pos) {
  final m = evalTerms(pos).material;
  return pos.turn == white ? m : -m;
}

/// The mover's material result after [afterMove] (opponent to move),
/// searching [depth] plies plus captures.
int materialOutcome(Position afterMove, {int depth = 2}) => -negamax(
      afterMove,
      depth,
      -mateScore - 1,
      mateScore + 1,
      1,
      evalFn: materialEval,
    );

/// Material [m] gains compared with passing the turn. A tactic's claimed
/// gain is believed only if this margin reaches it.
int materialMargin(Position pos, Move m, {int depth = 2}) =>
    materialOutcome(pos.makeMove(m), depth: depth) -
    materialOutcome(pos.passTurn(), depth: depth);
