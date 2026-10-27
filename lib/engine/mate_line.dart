import 'dart:math';

import 'move.dart';
import 'position.dart';
import 'search.dart';

/// True if [m] forces checkmate within [n] of the mover's moves, counting [m]
/// itself: it mates at once, or every reply still allows mate in [n] - 1.
bool leadsToMate(Position pos, Move m, int n) {
  final next = pos.makeMove(m);
  final replies = next.legalMoves();
  if (replies.isEmpty) return next.inCheck;
  if (n <= 1) return false;
  return replies.every((r) => mateIn(next.makeMove(r), n - 1) != null);
}

/// The defender's reply in [pos] (after the mating side's move) that holds out
/// longest against a mate in at most [n] more moves; ties are broken at
/// random. Null when the defender has no legal move.
Move? stubbornDefence(Position pos, int n, [Random? random]) {
  final replies = pos.legalMoves();
  if (replies.isEmpty) return null;
  var longest = 0;
  final byLength = <Move, int>{};
  for (final r in replies) {
    final after = pos.makeMove(r);
    var len = 1;
    while (len < n && mateIn(after, len) == null) {
      len++;
    }
    byLength[r] = len;
    if (len > longest) longest = len;
  }
  final best = [
    for (final e in byLength.entries)
      if (e.value == longest) e.key,
  ];
  return best[(random ?? Random()).nextInt(best.length)];
}
