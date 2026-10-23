import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// (slider, front piece, back piece): a [color] slider sees two enemy
/// pieces in a row along one line.
typedef Line = (int, int, int);

Set<Line> linesOf(Position pos, int color) {
  final out = <Line>{};
  for (var x = 0; x < 64; x++) {
    final p = pos.squares[x];
    if (p == empty || pieceColor(p) != color) continue;
    final ty = pieceType(p);
    if (ty != bishop && ty != rook && ty != queen) continue;
    final dirs = ty == bishop
        ? kBishopDirs
        : ty == rook
            ? kRookDirs
            : [...kBishopDirs, ...kRookDirs];
    for (final d in dirs) {
      var nr = rankOf(x) + d[0];
      var nf = fileOf(x) + d[1];
      int? front;
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final y = squareOf(nr, nf);
        final q = pos.squares[y];
        if (q != empty) {
          if (pieceColor(q) == color) break;
          if (front == null) {
            front = y;
          } else {
            out.add((x, front, y));
            break;
          }
        }
        nr += d[0];
        nf += d[1];
      }
    }
  }
  return out;
}

/// Pins and skewers newly created by the move.
List<Insight> detectLines(Position pos, Move m, Position next) {
  final s = pos.turn;
  final before = linesOf(pos, s);
  final out = <Insight>[];

  for (final (x, front, back) in linesOf(next, s)) {
    if (before.contains((x, front, back)) || !isSafe(next, x, s)) continue;

    final fv = attackValue(pieceType(next.squares[front]));
    final bv = attackValue(pieceType(next.squares[back]));
    final slider = pieceName(pieceType(next.squares[x]));
    final fn = pieceName(pieceType(next.squares[front]));
    final bn = pieceName(pieceType(next.squares[back]));
    final who = colorName(s);

    if (bv > fv) {
      final String text;
      if (pieceType(next.squares[back]) == king) {
        text = 'The $slider on ${squareName(x)} pins the $fn on '
            '${squareName(front)} to the king on ${squareName(back)}: the '
            '$fn cannot move without exposing the king.';
      } else {
        text = 'The $slider on ${squareName(x)} pins the $fn on '
            '${squareName(front)} to the $bn on ${squareName(back)}: if the '
            '$fn moves, $who wins the $bn.';
      }
      out.add(Insight(
        idea: Idea.pin,
        move: m,
        squares: [x, front, back],
        gain: 0,
        level: 4,
        text: text,
      ));
    } else if (fv > bv) {
      final frontDefended = attackersOf(next, front, 1 - s).isNotEmpty;
      final forced = pieceType(next.squares[front]) == king ||
          !frontDefended ||
          fv > attackValue(pieceType(next.squares[x]));
      if (!forced) continue; // the front piece can simply stay put

      final backDefended = attackersOf(next, back, 1 - s).isNotEmpty;
      final gain =
          backDefended ? bv - attackValue(pieceType(next.squares[x])) : bv;
      if (gain <= 0) continue;

      final frontName = pieceType(next.squares[front]) == king
          ? 'the king on ${squareName(front)}: the king'
          : 'the $fn on ${squareName(front)}: it';
      out.add(Insight(
        idea: Idea.skewer,
        move: m,
        squares: [x, front, back],
        gain: gain,
        level: 4,
        text: 'The $slider on ${squareName(x)} skewers $frontName must '
            'move, and then $who takes the $bn on ${squareName(back)}.',
      ));
    }
  }
  return out;
}
