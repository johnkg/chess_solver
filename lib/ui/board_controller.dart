import 'package:flutter/foundation.dart';

import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/position.dart';

/// Holds a position, the move history and the current selection. Screens
/// feed it taps and listen for changes.
///
/// Promotions always become a queen.
class BoardController extends ChangeNotifier {
  BoardController([Position? start]) : _position = start ?? Position.start();

  Position _position;
  final List<(Position, Move)> _history = [];
  int? _selected;
  Set<int> _targets = const <int>{};

  Position get position => _position;

  /// Square of the selected piece, or null.
  int? get selected => _selected;

  /// Squares the selected piece can go to.
  Set<int> get targets => _targets;

  /// Moves played since the last [setPosition].
  int get ply => _history.length;

  bool get canUndo => _history.isNotEmpty;

  Move? get lastMove => _history.isEmpty ? null : _history.last.$2;

  /// Position before [lastMove], or null.
  Position? get previous => _history.isEmpty ? null : _history.last.$1;

  /// Piece types [color] has captured so far, most valuable first. Counts
  /// en passant; promotions do not change it.
  List<int> capturedBy(int color) {
    final out = <int>[];
    for (final (before, move) in _history) {
      if (pieceColor(before.squares[move.from]) != color) continue;
      final victim = before.squares[move.to];
      if (victim != empty) {
        out.add(pieceType(victim));
      } else if (move.flag == Move.enPassant) {
        out.add(pawn);
      }
    }
    out.sort((a, b) => pieceValue(b).compareTo(pieceValue(a)));
    return out;
  }

  /// Squares of the last move, for tinting.
  Set<int> get lastMoveSquares {
    final m = lastMove;
    return m == null ? const <int>{} : {m.from, m.to};
  }

  /// Handles a tap on [square]. Returns the move if the tap completed one.
  Move? tap(int square) {
    final from = _selected;
    if (from != null && _targets.contains(square)) {
      final moves = _position
          .legalMoves()
          .where((m) => m.from == from && m.to == square)
          .toList();
      if (moves.isNotEmpty) {
        final m = moves.firstWhere(
          (m) => m.promotion == queen,
          orElse: () => moves.first,
        );
        play(m);
        return m;
      }
    }

    final p = _position.squares[square];
    if (p != empty && pieceColor(p) == _position.turn && square != from) {
      _selected = square;
      _targets = {
        for (final m in _position.legalMoves())
          if (m.from == square) m.to,
      };
    } else {
      _selected = null;
      _targets = const <int>{};
    }
    notifyListeners();
    return null;
  }

  /// Plays [m], which must be legal.
  void play(Move m) {
    _history.add((_position, m));
    _position = _position.makeMove(m);
    _selected = null;
    _targets = const <int>{};
    notifyListeners();
  }

  /// Takes back the last move.
  void undo() {
    if (_history.isEmpty) return;
    _position = _history.removeLast().$1;
    _selected = null;
    _targets = const <int>{};
    notifyListeners();
  }

  /// Starts over from [p] with an empty history.
  void setPosition(Position p) {
    _position = p;
    _history.clear();
    _selected = null;
    _targets = const <int>{};
    notifyListeners();
  }
}
