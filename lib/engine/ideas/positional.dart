import '../eval.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// Quiet-move reasons: castling, development, fighting for the center.
/// Only used when no tactic explains the move.
List<Insight> detectPositional(Position pos, Move m, Position next) {
  final s = pos.turn;
  final sign = s == white ? 1 : -1;
  final who = colorName(s);
  final piece = pieceName(pieceType(pos.squares[m.from]));

  if (m.flag == Move.castleKing || m.flag == Move.castleQueen) {
    final side = m.flag == Move.castleKing ? 'kingside' : 'queenside';
    return [
      Insight(
        idea: Idea.castling,
        move: m,
        squares: [m.from, m.to],
        gain: 0,
        level: 3,
        text: '$who castles $side: the king gets behind its pawns and the '
            'rook joins the game.',
      ),
    ];
  }

  final a = evalTerms(pos);
  final b = evalTerms(next);
  final dev = sign * (b.development - a.development);
  final cen = sign * (b.center - a.center);

  if (dev > 0) {
    return [
      Insight(
        idea: Idea.development,
        move: m,
        squares: [m.from, m.to],
        gain: 0,
        level: 3,
        text: 'Develops the $piece from ${squareName(m.from)} to '
            '${squareName(m.to)}: pieces in play beat pieces at home.',
      ),
    ];
  }
  if (cen > 0) {
    return [
      Insight(
        idea: Idea.center,
        move: m,
        squares: [m.from, m.to],
        gain: 0,
        level: 3,
        text: 'The $piece to ${squareName(m.to)} fights for the center, '
            'where pieces control the most squares.',
      ),
    ];
  }
  return const [];
}
