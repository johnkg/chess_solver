import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// One piece, after the move, newly attacks two things the opponent cannot
/// both save (or a king plus something else).
List<Insight> detectFork(Position pos, Move m, Position next) {
  final s = pos.turn;
  final to = m.to;
  final forker = next.squares[to];
  if (forker == empty || !isSafe(next, to, s)) return const [];

  var kingAttacked = false;
  final gains = <int>[];
  final targets = <int>[];
  for (final t in attackedSquares(next, to)) {
    final p = next.squares[t];
    if (p == empty || pieceColor(p) == s) continue;
    if (attackersOf(pos, t, s).isNotEmpty) continue; // not a new threat
    if (pieceType(p) == king) {
      kingAttacked = true;
      targets.add(t);
      continue;
    }
    final defended = attackersOf(next, t, 1 - s).isNotEmpty;
    final g = defended
        ? attackValue(pieceType(p)) - attackValue(pieceType(forker))
        : attackValue(pieceType(p));
    if (g > 0) {
      gains.add(g);
      targets.add(t);
    }
  }
  gains.sort((a, b) => b.compareTo(a));

  final int claim;
  if (kingAttacked && gains.isNotEmpty) {
    claim = gains[0];
  } else if (!kingAttacked && gains.length >= 2) {
    claim = gains[1];
  } else {
    return const [];
  }

  final who = colorName(s);
  final piece = pieceName(pieceType(pos.squares[m.from]));
  final desc = [
    for (final t in targets)
      'the ${pieceName(pieceType(next.squares[t]))} on ${squareName(t)}',
  ];
  final listed = desc.length <= 2
      ? desc.join(' and ')
      : '${desc.sublist(0, desc.length - 1).join(', ')} and ${desc.last}';
  final follow = kingAttacked
      ? '${colorName(1 - s)} must answer the check, so $who then wins the '
          'other piece.'
      : '${colorName(1 - s)} can only save one of them.';

  return [
    Insight(
      idea: Idea.fork,
      move: m,
      squares: [to, ...targets],
      gain: claim,
      level: 4,
      text: '${capitalize(piece)} to ${squareName(to)} forks $listed. '
          '$follow',
    ),
  ];
}
