import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// A capture that wins material once the whole exchange on the square is
/// counted (static exchange evaluation).
List<Insight> detectCapture(Position pos, Move m, Position next) {
  if (m.promotion != 0) return const [];
  final victim = pos.squares[m.to];
  if (victim == empty && m.flag != Move.enPassant) return const [];
  if (victim != empty && pieceType(victim) == king) return const [];

  final s = pos.turn;
  final net = seeCapture(pos, m);
  if (net <= 0) return const [];

  final who = colorName(s);
  final piece = pieceName(pieceType(pos.squares[m.from]));
  final vname = victim != empty ? pieceName(pieceType(victim)) : 'pawn';
  final free = attackersOf(next, m.to, 1 - s).isEmpty;
  final where = squareName(m.to);

  final text = free
      ? '${capitalize(piece)} takes the $vname on $where. Nothing can '
          'recapture, so $who wins a free $vname.'
      : '${capitalize(piece)} takes the $vname on $where. It can be '
          'recaptured, but the $vname is worth more than the $piece, so '
          '$who still comes out ahead.';

  return [
    Insight(
      idea: Idea.hangingPiece,
      move: m,
      squares: [m.from, m.to],
      gain: net,
      level: 3,
      text: text,
    ),
  ];
}
