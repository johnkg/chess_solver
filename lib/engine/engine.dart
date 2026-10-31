import 'dart:math' show log, max;

import 'move.dart';
import 'piece.dart';
import 'play_eval.dart';
import 'position.dart';
import 'search.dart' show isMateScore, mateScore;
import 'tt.dart';

// --- Search limits ---

/// Larger than any real score: the open end of an alpha-beta window.
const int _infinity = mateScore + 1;

/// Deepest line searched, quiescence included.
const int _maxPly = 60;

/// Check extensions stop beyond this ply so a long checking line ends.
const int _maxCheckExtensionPly = 40;

/// Killer-move slots; deeper plies (and quiescence) use none.
const int _killerPlyLimit = 64;
const int _noKillerPly = _killerPlyLimit;

/// Draw by the fifty-move rule, in half-moves since a capture or pawn move.
const int _fiftyMoveHalfmoves = 100;

/// A position can only repeat after this many reversible half-moves.
const int _earliestRepetitionHalfmoves = 4;

/// Moves tried when the caller does not say how wide the root window is.
const int _defaultMoveMargin = 50;

// --- Time control ---

/// The clock is read once per this many nodes (a power of two).
const int _nodesPerClockCheck = 1024;

/// How long the async search works before yielding to the event loop.
const int _yieldAfterMillis = 20;

/// Stop deepening once this share of the time is used: the next depth takes
/// several times longer than the last, so it would not finish.
const double _nextDepthTimeShare = 0.6;

// --- Transposition table size ---

const int _smallTableBits = 16;
const int _largeTableBits = 18;
const int _smallTableMaxDepth = 3;

// --- Null move, late-move reductions and static pruning ---

const int _nullMoveMinDepth = 3;

/// Depth taken off a null-move search: the move itself plus two more plies.
const int _nullMoveDepthDrop = 3;

const int _lateMoveReductionMinDepth = 3;

/// Quiet moves after this many legal ones are searched shallower first.
const int _lateMovesStartAfter = 3;
const double _reductionDivisor = 2.0;

/// Futility and reverse futility only apply this close to the leaves.
const int _staticPruningMaxDepth = 3;
const int _futilityMaxDepth = 2;

/// Centipawn margins by depth (index = depth - 1): a quiet move this far
/// below alpha cannot catch up.
const List<int> _futilityMargins = [150, 320];

/// A node whose eval beats beta by this much per remaining ply is cut.
const int _reverseFutilityMarginPerPly = 130;

/// Quiescence skips a capture that cannot lift the eval to alpha even with
/// this much slack on top of the captured piece.
const int _deltaPruningMargin = 200;

// --- Move ordering scores (higher is tried first) ---

const int _ttMoveOrder = 1000000;
const int _captureOrder = 100000;
const int _promotionOrder = 90000;
const int _firstKillerOrder = 80000;
const int _secondKillerOrder = 79000;

/// Captures sort by victim value times this, minus attacker value over
/// [_attackerOrderDivisor] (most valuable victim, least valuable attacker).
const int _victimOrderWeight = 10;
const int _attackerOrderDivisor = 10;

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

/// Iterative-deepening alpha-beta with quiescence, null-move pruning, late
/// move reductions that grow with depth and move number, killer moves and the history heuristic. Meant for the
/// computer opponent: it stops when its time budget runs out and keeps the
/// last finished depth.
class Searcher {
  /// [useTable] turns the transposition table off (tests and the duel tool
  /// compare both).
  ///
  /// [pruning] turns on futility pruning, reverse futility and skipping bad
  /// captures in quiescence.
  Searcher({this.useTable = true, this.pruning = true});

  final bool useTable;
  final bool pruning;
  TranspositionTable? _tt;

  final Stopwatch _clock = Stopwatch();
  int _budgetMs = 0;
  bool _timed = false;
  int nodes = 0;

  final List<List<Move?>> _killers = [
    for (var i = 0; i < _killerPlyLimit; i++) [null, null],
  ];
  /// Quiet moves that caused cutoffs, by [_historyIndex].
  final List<int> _history = List<int>.filled(boardSquares * boardSquares, 0);

  /// Set to true to abandon a running search; [searchAsync] then returns null.
  bool cancelled = false;

  SearchResult? _result;

  /// Keys of the positions on the current line, game history first. A
  /// position that is already here scores as a draw.
  final List<String> _path = [];
  final Stopwatch _slice = Stopwatch();

  /// Best moves in [pos], or null when there is no legal move. Searches up to
  /// [maxDepth] plies or [millis] milliseconds, whichever comes first (depth 1
  /// always finishes). Moves within [margin] centipawns of the best are
  /// scored exactly; the rest are dropped.
  SearchResult? search(
    Position pos, {
    required int maxDepth,
    required int millis,
    int margin = _defaultMoveMargin,
    List<String> history = const [],
  }) {
    for (final _ in _run(pos, maxDepth, millis, margin, history)) {}
    return _result;
  }

  /// Same as [search], but hands control back to the event loop every few
  /// milliseconds so the UI can repaint (a clock keeps ticking, a button still
  /// answers). Returns null when [cancelled] is set or there is no legal move.
  Future<SearchResult?> searchAsync(
    Position pos, {
    required int maxDepth,
    required int millis,
    int margin = _defaultMoveMargin,
    List<String> history = const [],
  }) async {
    for (final _ in _run(pos, maxDepth, millis, margin, history)) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled) return null;
    }
    return cancelled ? null : _result;
  }

  /// The search itself. It yields (with nothing) between root moves once a
  /// slice of work has taken long enough, and leaves the answer in [_result].
  /// [history] holds the [Position.repetitionKey] of every earlier position
  /// in the game (not [pos] itself).
  Iterable<void> _run(
    Position pos,
    int maxDepth,
    int millis,
    int margin,
    List<String> history,
  ) sync* {
    _result = null;
    _path
      ..clear()
      ..addAll(history)
      ..add(pos.repetitionKey);
    final legal = pos.legalMoves();
    if (legal.isEmpty) return;
    if (legal.length == 1) {
      _result = SearchResult([(legal.first, 0)], 0, 0);
      return;
    }

    _clock
      ..reset()
      ..start();
    _slice
      ..reset()
      ..start();
    _budgetMs = millis;
    nodes = 0;
    _tt = useTable ? TranspositionTable(maxDepth <= _smallTableMaxDepth ? _smallTableBits : _largeTableBits) : null;
    var ordered = _orderRoot(pos, legal);
    SearchResult? done;

    for (var depth = 1; depth <= maxDepth; depth++) {
      _timed = depth > 1;
      try {
        final out = <(Move, int)>[];
        var best = -_infinity;
        for (final m in ordered) {
          final next = pos.makeMove(m);
          final floor = out.isEmpty ? -_infinity : best - margin;
          final score = -_negamax(next, depth - 1, -_infinity, -floor, 1, true);
          if (out.isEmpty || score > floor) {
            out.add((m, score));
            if (score > best) best = score;
          }
          if (_slice.elapsedMilliseconds >= _yieldAfterMillis) {
            yield null;
            _slice
              ..reset()
              ..start();
          }
        }
        out.removeWhere((e) => e.$2 < best - margin);
        out.sort((a, b) => b.$2.compareTo(a.$2));
        done = SearchResult(out, depth, nodes);
        ordered = [for (final e in out) e.$1];
        final rest = legal.where((m) => !ordered.contains(m));
        ordered = [...ordered, ...rest];
        if (isMateScore(out.first.$2)) break;
      } on _Stop {
        break;
      }
      if (_clock.elapsedMilliseconds > millis * _nextDepthTimeShare) break;
    }
    _clock.stop();
    _result = done ?? SearchResult([(legal.first, 0)], 0, nodes);
  }

  /// Plies to cut from a quiet late move: more for deeper searches and for
  /// moves further down the list.
  static int _reduction(int depth, int moveNumber) {
    final r = (log(depth) * log(moveNumber) / _reductionDivisor).floor();
    return r < 1 ? 1 : (r > depth - 2 ? max(1, depth - 2) : r);
  }

  List<Move> _orderRoot(Position pos, List<Move> moves) {
    final list = [...moves];
    list.sort((a, b) => _orderKey(pos, b, 0).compareTo(_orderKey(pos, a, 0)));
    return list;
  }

  /// Counts a node and stops the search when cancelled or out of time.
  void _tick() {
    nodes++;
    if (cancelled) throw const _Stop();
    final timeToCheckClock = (nodes & (_nodesPerClockCheck - 1)) == 0;
    if (_timed && timeToCheckClock && _clock.elapsedMilliseconds > _budgetMs) {
      throw const _Stop();
    }
  }

  static int _historyIndex(Move m) => m.from * boardSquares + m.to;

  static bool _isCapture(Position pos, Move m) =>
      pos.squares[m.to] != empty || m.flag == Move.enPassant;

  static bool _isQuiet(Position pos, Move m) => !_isCapture(pos, m) && m.promotion == 0;

  /// Indexes of [keys] from the highest key to the lowest.
  static List<int> _indexesByDescendingKey(List<int> keys) =>
      List<int>.generate(keys.length, (i) => i)..sort((a, b) => keys[b].compareTo(keys[a]));

  /// How early to try [m]: the table's move, then captures (most valuable
  /// victim first), promotions, killers, then quiet moves by history.
  int _orderKey(Position pos, Move m, int ply, [int ttMove = 0]) {
    if (ttMove != 0 && TranspositionTable.sameMove(ttMove, m)) return _ttMoveOrder;
    if (_isCapture(pos, m)) {
      final victim = pos.squares[m.to];
      final victimValue = victim == empty ? centipawnValue[pawn] : centipawnValue[pieceType(victim)];
      final attackerValue = centipawnValue[pieceType(pos.squares[m.from])];
      return _captureOrder + victimValue * _victimOrderWeight - attackerValue ~/ _attackerOrderDivisor;
    }
    if (m.promotion != 0) return _promotionOrder + centipawnValue[m.promotion];
    if (ply < _killerPlyLimit) {
      final killers = _killers[ply];
      if (killers[0] == m) return _firstKillerOrder;
      if (killers[1] == m) return _secondKillerOrder;
    }
    return _history[_historyIndex(m)];
  }

  /// Remembers a quiet move that caused a cutoff at [ply].
  void _recordCutoff(Move m, int ply, int depth) {
    if (ply >= _killerPlyLimit) return;
    final killers = _killers[ply];
    if (killers[0] != m) {
      killers[1] = killers[0];
      killers[0] = m;
    }
    _history[_historyIndex(m)] += depth * depth;
  }

  int _negamax(Position pos, int depth, int alpha, int beta, int ply, bool allowNull) {
    _tick();
    if (pos.halfmove >= _fiftyMoveHalfmoves) return 0;

    // A position seen before on this line (or earlier in the game) is a
    // repetition. Only reversible-move stretches can repeat.
    String? repetitionKey;
    if (pos.halfmove >= _earliestRepetitionHalfmoves) {
      repetitionKey = pos.repetitionKey;
      if (_path.contains(repetitionKey)) return 0;
    }

    final inCheck = pos.inCheck;
    if (inCheck && ply < _maxCheckExtensionPly) depth++;
    if (depth <= 0 || ply >= _maxPly) return _quiesce(pos, alpha, beta, ply);

    final table = _tt;
    var slotHash = 0;
    var checkHash = 0;
    var tableMove = 0;
    final originalAlpha = alpha;
    final originalBeta = beta;
    if (table != null) {
      (slotHash, checkHash) = TranspositionTable.hashOf(pos);
      final slot = table.find(slotHash, checkHash);
      if (slot >= 0) {
        tableMove = table.moveAt(slot);
        if (table.depthAt(slot) >= depth) {
          final stored = table.scoreAt(slot, ply);
          final bound = table.boundAt(slot);
          if (bound == ScoreBound.exact) return stored;
          if (bound == ScoreBound.lower) {
            if (stored > alpha) alpha = stored;
          } else if (stored < beta) {
            beta = stored;
          }
          if (alpha >= beta) return stored;
        }
      }
    }

    if (allowNull && !inCheck && depth >= _nullMoveMinDepth && _hasPieces(pos, pos.turn)) {
      final passed = pos.passTurn();
      final score = -_negamax(passed, depth - _nullMoveDepthDrop, -beta, -beta + 1, ply + 1, false);
      if (score >= beta) return beta;
    }

    // Static pruning, only in zero-window nodes away from mates and checks.
    // Quiet moves that cannot lift the eval (plus a margin) to alpha are
    // skipped below.
    int? futilityBound;
    final isZeroWindow = beta - alpha == 1;
    if (pruning &&
        !inCheck &&
        depth <= _staticPruningMaxDepth &&
        isZeroWindow &&
        !isMateScore(alpha)) {
      final staticEval = playEval(pos);
      if (staticEval - _reverseFutilityMarginPerPly * depth >= beta) return staticEval;
      if (depth <= _futilityMaxDepth) futilityBound = staticEval + _futilityMargins[depth - 1];
    }

    final moves = pos.pseudoLegalMoves();
    final order = _indexesByDescendingKey([
      for (final m in moves) _orderKey(pos, m, ply, tableMove),
    ]);

    var legalMoveCount = 0;
    var bestScore = -_infinity;
    Move? bestMove;
    if (repetitionKey != null) _path.add(repetitionKey);
    for (final i in order) {
      final move = moves[i];
      final next = pos.makeMove(move);
      if (!pos.keepsKingSafe(next)) continue;
      legalMoveCount++;
      final isQuiet = _isQuiet(pos, move);
      final isFirstMove = legalMoveCount == 1;

      final cannotReachAlpha = futilityBound != null && futilityBound <= alpha;
      if (cannotReachAlpha && !isFirstMove && isQuiet && !next.inCheck && !isMateScore(bestScore)) {
        continue;
      }

      int score;
      if (isFirstMove) {
        score = -_negamax(next, depth - 1, -beta, -alpha, ply + 1, true);
      } else {
        final isLateQuietMove = isQuiet &&
            !inCheck &&
            depth >= _lateMoveReductionMinDepth &&
            legalMoveCount > _lateMovesStartAfter;
        final reduction = isLateQuietMove ? _reduction(depth, legalMoveCount) : 0;
        score = -_negamax(next, depth - 1 - reduction, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && (reduction > 0 || score < beta)) {
          score = -_negamax(next, depth - 1, -beta, -alpha, ply + 1, true);
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        if (isQuiet) _recordCutoff(move, ply, depth);
        break;
      }
    }
    if (repetitionKey != null) _path.removeLast();

    if (legalMoveCount == 0) return inCheck ? -mateScore + ply : 0;
    if (table != null) {
      final bound = bestScore <= originalAlpha
          ? ScoreBound.upper
          : bestScore >= originalBeta
              ? ScoreBound.lower
              : ScoreBound.exact;
      table.store(slotHash, checkHash, depth, bestScore, bound, bestMove, ply);
    }
    return bestScore;
  }

  int _quiesce(Position pos, int alpha, int beta, int ply) {
    _tick();
    final standPat = playEval(pos);
    if (standPat >= beta) return standPat;
    if (standPat > alpha) alpha = standPat;
    if (ply >= _maxPly) return alpha;

    final tactical = [
      for (final m in pos.pseudoLegalMoves())
        if (!_isQuiet(pos, m)) m,
    ];
    final order = _indexesByDescendingKey([
      for (final m in tactical) _orderKey(pos, m, _noKillerPly),
    ]);
    for (final i in order) {
      final move = tactical[i];
      final victim = pos.squares[move.to];
      final gain = victim == empty ? centipawnValue[pawn] : centipawnValue[pieceType(victim)];
      final cannotCatchUp = standPat + gain + _deltaPruningMargin < alpha;
      if (cannotCatchUp && move.promotion == 0) continue;
      final next = pos.makeMove(move);
      if (!pos.keepsKingSafe(next)) continue;
      if (pruning && _losesMaterialCapturing(pos, move, next, gain)) continue;
      final score = -_quiesce(next, -beta, -alpha, ply + 1);
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// True for taking a defended piece with a more valuable one (not a
  /// promotion): after the recapture that loses material.
  static bool _losesMaterialCapturing(Position pos, Move move, Position next, int gain) {
    if (move.promotion != 0 || pos.squares[move.to] == empty) return false;
    final attackerValue = centipawnValue[pieceType(pos.squares[move.from])];
    return attackerValue > gain && next.isAttacked(move.to, next.turn);
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
