import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// A capture that is not a plain win, but takes away the only protection of
/// a piece that was already under attack.
List<Insight> detectRemoveDefender(Position pos, Move m, Position next) {
  final victim = pos.squares[m.to];
  if (victim == empty || m.promotion != 0 || pieceType(victim) == king) {
    return const [];
  }
  final s = pos.turn;
  final dSq = m.to;
  final cap = seeCapture(pos, m);
  if (cap > 0) return const []; // a plain win: detectCapture explains it

  int? bestSq;
  var bestGain = 0;
  for (var tSq = 0; tSq < 64; tSq++) {
    final t = pos.squares[tSq];
    if (t == empty || pieceColor(t) == s || pieceType(t) == king) continue;
    if (tSq == dSq) continue;
    if (attackersOf(pos, tSq, s).isEmpty) continue; // was not attacked
    if (!attackersOf(pos, tSq, 1 - s).contains(dSq)) continue; // not its guard

    final mine = attackersOf(next, tSq, s);
    if (mine.isEmpty) continue;
    final theirs = attackersOf(next, tSq, 1 - s);

    var lowestMine = 1 << 30;
    for (final a in mine) {
      final v = attackValue(pieceType(next.squares[a]));
      if (v < lowestMine) lowestMine = v;
    }
    final tv = attackValue(pieceType(t));
    var g = theirs.isEmpty ? tv : tv - lowestMine;
    g += cap; // cap <= 0: what the capture itself costs
    if (g > 0 && (bestSq == null || g > bestGain)) {
      bestSq = tSq;
      bestGain = g;
    }
  }
  if (bestSq == null) return const [];

  final who = colorName(s);
  final piece = pieceName(pieceType(pos.squares[m.from]));
  return [
    Insight(
      idea: Idea.removingDefender,
      move: m,
      squares: [m.from, dSq, bestSq],
      gain: bestGain,
      level: 4,
      text: '${capitalize(piece)} takes the ${pieceName(pieceType(victim))} '
          'on ${squareName(dSq)}. That piece was defending the '
          '${pieceName(pieceType(pos.squares[bestSq]))} on '
          '${squareName(bestSq)}, which is now short of protection, so $who '
          'threatens to win it.',
    ),
  ];
}
