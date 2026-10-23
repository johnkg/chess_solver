import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// Checkmate, and the back-rank mate pattern.
List<Insight> detectMate(Position pos, Move m, Position next) {
  if (!next.inCheck || next.legalMoves().isNotEmpty) return const [];

  final s = pos.turn;
  final piece = pieceName(pieceType(pos.squares[m.from]));
  final k = next.kingSquare(1 - s);
  final home = s == white ? 7 : 0;
  final moverAfter = next.squares[m.to];
  final moverType = pieceType(moverAfter);

  if (moverType == knight) {
    final around = <int>[];
    for (final d in kKingSteps) {
      final nr = rankOf(k) + d[0];
      final nf = fileOf(k) + d[1];
      if (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) around.add(squareOf(nr, nf));
    }
    final boxed = around.every((c) =>
        next.squares[c] != empty && pieceColor(next.squares[c]) == 1 - s);
    if (boxed) {
      return [
        Insight(
          idea: Idea.smotheredMate,
          move: m,
          squares: [m.to, k, ...around],
          gain: 100000,
          level: 4,
          text: 'Smothered mate. The ${colorName(1 - s).toLowerCase()} king on '
              '${squareName(k)} is boxed in by its own pieces, so the knight '
              'on ${squareName(m.to)} gives check and nothing can capture it '
              'or help the king.',
        ),
      ];
    }
  }

  if (rankOf(k) == home &&
      rankOf(m.to) == home &&
      (moverType == rook || moverType == queen)) {
    final front = home + (s == white ? -1 : 1);
    final cells = [
      for (var ff = fileOf(k) - 1; ff <= fileOf(k) + 1; ff++)
        if (ff >= 0 && ff < 8) squareOf(front, ff),
    ];
    final blocked = cells.every((c) =>
        next.squares[c] != empty && pieceColor(next.squares[c]) == 1 - s);
    if (blocked) {
      final names = cells.map(squareName).join(', ');
      return [
        Insight(
          idea: Idea.backRankMate,
          move: m,
          squares: [m.to, k, ...cells],
          gain: 100000,
          level: 4,
          text: 'Checkmate. The ${colorName(1 - s).toLowerCase()} king on '
              '${squareName(k)} is trapped on its back rank by its own '
              'pieces on $names, and the ${pieceName(moverType)} on '
              '${squareName(m.to)} attacks it along the rank.',
        ),
      ];
    }
  }

  return [
    Insight(
      idea: Idea.checkmate,
      move: m,
      squares: [m.to, k],
      gain: 100000,
      level: 4,
      text: 'Checkmate. The $piece to ${squareName(m.to)} attacks the king '
          'on ${squareName(k)} and it has no safe square and nothing can '
          'block or capture.',
    ),
  ];
}
