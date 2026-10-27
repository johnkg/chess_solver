import 'move.dart';
import 'piece.dart';
import 'play_eval.dart';
import 'position.dart';
import 'search.dart' show mateScore;

/// Result of [Searcher.search]: the moves scoring within the margin of the
/// best one, best first. Scores are centipawns for the side to move.
class SearchResult {
  const SearchResult(this.moves, this.depth, this.nodes);

  final List<(Move, int)> moves;

  /// Deepest iteration that finished.
  final int depth;
  final int nodes;

  (Move, int) get best => moves.first;
}

class _Stop implements Exception {
  const _Stop();
}

const List<int> _victimValue = [0, 100, 320, 330, 500, 900, 0];

/// Iterative-deepening alpha-beta with quiescence, null-move pruning, late
/// move reductions, killer moves and the history heuristic. Meant for the
/// computer opponent: it stops when its time budget runs out and keeps the
/// last finished depth.
class Searcher {
  final Stopwatch _clock = Stopwatch();
  int _budgetMs = 1000;
  bool _timed = false;
  int nodes = 0;

  final List<List<Move?>> _killers = [
    for (var i = 0; i < 64; i++) [null, null],
  ];
  final List<int> _history = List<int>.filled(64 * 64, 0);

  /// Best moves in [pos], or null when there is no legal move. Searches up to
  /// [maxDepth] plies or [millis] milliseconds, whichever comes first (depth 1
  /// always finishes). Moves within [margin] centipawns of the best are
  /// scored exactly; the rest are dropped.
  SearchResult? search(
    Position pos, {
    required int maxDepth,
    required int millis,
    int margin = 50,
  }) {
    final legal = pos.legalMoves();
    if (legal.isEmpty) return null;
    if (legal.length == 1) return SearchResult([(legal.first, 0)], 0, 0);

    _clock
      ..reset()
      ..start();
    _budgetMs = millis;
    nodes = 0;
    var ordered = _orderRoot(pos, legal);
    SearchResult? done;

    for (var depth = 1; depth <= maxDepth; depth++) {
      _timed = depth > 1;
      try {
        final scored = _rootSearch(pos, ordered, depth, margin);
        done = SearchResult(scored, depth, nodes);
        ordered = [for (final e in scored) e.$1];
        final rest = legal.where((m) => !ordered.contains(m));
        ordered = [...ordered, ...rest];
        if (isMate(scored.first.$2)) break;
      } on _Stop {
        break;
      }
      if (_clock.elapsedMilliseconds > millis * 0.6) break; // next depth will not finish
    }
    _clock.stop();
    return done ?? SearchResult([(legal.first, 0)], 0, nodes);
  }

  bool isMate(int score) => score.abs() > mateScore - 1000;

  List<Move> _orderRoot(Position pos, List<Move> moves) {
    final list = [...moves];
    list.sort((a, b) => _orderKey(pos, b, 0).compareTo(_orderKey(pos, a, 0)));
    return list;
  }

  List<(Move, int)> _rootSearch(Position pos, List<Move> moves, int depth, int margin) {
    final out = <(Move, int)>[];
    var best = -mateScore - 1;
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      final next = pos.makeMove(m);
      final floor = out.isEmpty ? -mateScore - 1 : best - margin;
      final score = -_negamax(next, depth - 1, -mateScore - 1, -floor, 1, true);
      if (out.isEmpty || score > floor) {
        out.add((m, score));
        if (score > best) best = score;
      }
    }
    out.removeWhere((e) => e.$2 < best - margin);
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  void _tick() {
    nodes++;
    if (_timed && (nodes & 1023) == 0 && _clock.elapsedMilliseconds > _budgetMs) {
      throw const _Stop();
    }
  }

  int _orderKey(Position pos, Move m, int ply) {
    final victim = pos.squares[m.to];
    if (victim != empty || m.flag == Move.enPassant) {
      final v = victim == empty ? 100 : _victimValue[pieceType(victim)];
      final a = _victimValue[pieceType(pos.squares[m.from])];
      return 100000 + v * 10 - a ~/ 10;
    }
    if (m.promotion != 0) return 90000 + _victimValue[m.promotion];
    if (ply < 64) {
      final k = _killers[ply];
      if (k[0] == m) return 80000;
      if (k[1] == m) return 79000;
    }
    return _history[m.from * 64 + m.to];
  }

  int _negamax(Position pos, int depth, int alpha, int beta, int ply, bool allowNull) {
    _tick();
    if (pos.halfmove >= 100) return 0;
    final inCheck = pos.inCheck;
    if (inCheck && ply < 40) depth++;
    if (depth <= 0 || ply >= 60) return _quiesce(pos, alpha, beta, ply);

    if (allowNull && !inCheck && depth >= 3 && _hasPieces(pos, pos.turn)) {
      final score = -_negamax(pos.passTurn(), depth - 3, -beta, -beta + 1, ply + 1, false);
      if (score >= beta) return beta;
    }

    final moves = pos.pseudoLegalMoves();
    final keys = [for (final m in moves) _orderKey(pos, m, ply)];
    final idx = List<int>.generate(moves.length, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));

    var legal = 0;
    var best = -mateScore - 1;
    for (final i in idx) {
      final m = moves[i];
      final next = pos.makeMove(m);
      final k = next.kingSquare(pos.turn);
      if (k >= 0 && next.isAttacked(k, 1 - pos.turn)) continue;
      legal++;
      final quiet = pos.squares[m.to] == empty && m.promotion == 0 && m.flag != Move.enPassant;
      int score;
      if (legal == 1) {
        score = -_negamax(next, depth - 1, -beta, -alpha, ply + 1, true);
      } else {
        final reduce = (quiet && !inCheck && depth >= 3 && legal > 4) ? 1 : 0;
        score = -_negamax(next, depth - 1 - reduce, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && (reduce > 0 || score < beta)) {
          score = -_negamax(next, depth - 1, -beta, -alpha, ply + 1, true);
        }
      }
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        if (quiet && ply < 64) {
          final kl = _killers[ply];
          if (kl[0] != m) {
            kl[1] = kl[0];
            kl[0] = m;
          }
          _history[m.from * 64 + m.to] += depth * depth;
        }
        break;
      }
    }
    if (legal == 0) return inCheck ? -mateScore + ply : 0;
    return best;
  }

  int _quiesce(Position pos, int alpha, int beta, int ply) {
    _tick();
    final stand = playEval(pos);
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    if (ply >= 60) return alpha;

    final moves = <Move>[];
    final keys = <int>[];
    for (final m in pos.pseudoLegalMoves()) {
      final capture = pos.squares[m.to] != empty || m.flag == Move.enPassant;
      if (!capture && m.promotion == 0) continue;
      moves.add(m);
      keys.add(_orderKey(pos, m, 99));
    }
    final idx = List<int>.generate(moves.length, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));
    for (final i in idx) {
      final m = moves[i];
      final victim = pos.squares[m.to];
      final gain = victim == empty ? 100 : _victimValue[pieceType(victim)];
      if (stand + gain + 200 < alpha && m.promotion == 0) continue; // cannot catch up
      final next = pos.makeMove(m);
      final k = next.kingSquare(pos.turn);
      if (k >= 0 && next.isAttacked(k, 1 - pos.turn)) continue;
      final score = -_quiesce(next, -beta, -alpha, ply + 1);
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  bool _hasPieces(Position pos, int color) {
    for (final p in pos.squares) {
      if (p == empty || pieceColor(p) != color) continue;
      final t = pieceType(p);
      if (t != pawn && t != king) return true;
    }
    return false;
  }
}
