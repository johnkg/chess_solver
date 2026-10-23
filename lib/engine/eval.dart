import 'piece.dart';
import 'position.dart';

/// Static evaluation split into named parts, in centipawns, from White's
/// point of view (positive = good for White). The names are what the
/// "why is this move good" text is built from.
class EvalTerms {
  final int material;
  final int center;
  final int development;
  final int kingSafety;

  const EvalTerms({
    this.material = 0,
    this.center = 0,
    this.development = 0,
    this.kingSafety = 0,
  });

  int get total => material + center + development + kingSafety;

  /// Term-by-term change from [before] to this. Positive = better for White.
  EvalTerms operator -(EvalTerms before) => EvalTerms(
        material: material - before.material,
        center: center - before.center,
        development: development - before.development,
        kingSafety: kingSafety - before.kingSafety,
      );

  Map<String, int> toMap() => {
        'material': material,
        'center': center,
        'development': development,
        'kingSafety': kingSafety,
      };

  @override
  String toString() => toMap().toString();
}

final Set<int> _center4 = {
  squareOf(3, 3),
  squareOf(3, 4),
  squareOf(4, 3),
  squareOf(4, 4),
};

/// c3..f6 without the four central squares.
final Set<int> _extCenter = {
  for (var r = 2; r < 6; r++)
    for (var f = 2; f < 6; f++) squareOf(r, f),
}..removeAll(_center4);

/// Starting squares of the knights and bishops, per colour.
final List<Set<int>> _homeMinors = [
  {squareOf(0, 1), squareOf(0, 2), squareOf(0, 5), squareOf(0, 6)},
  {squareOf(7, 1), squareOf(7, 2), squareOf(7, 5), squareOf(7, 6)},
];

/// Named evaluation terms for [pos], White minus Black.
EvalTerms evalTerms(Position pos) {
  var material = 0;
  var center = 0;
  var development = 0;
  var kingSafety = 0;

  for (var x = 0; x < 64; x++) {
    final p = pos.squares[x];
    if (p == empty) continue;
    final c = pieceColor(p);
    final ty = pieceType(p);
    final sign = c == white ? 1 : -1;

    material += sign * pieceValue(ty) * 100;

    if (ty == pawn) {
      if (_center4.contains(x)) {
        center += sign * 30;
      } else if (_extCenter.contains(x)) {
        center += sign * 10;
      }
    } else if (ty == knight || ty == bishop) {
      if (_center4.contains(x)) {
        center += sign * 20;
      } else if (_extCenter.contains(x) && ty == knight) {
        center += sign * 10;
      }
      if (_homeMinors[c].contains(x)) development -= sign * 15;
    } else if (ty == king) {
      final r = rankOf(x);
      final f = fileOf(x);
      if (r == (c == white ? 0 : 7)) {
        final shieldRank = r + (c == white ? 1 : -1);
        var shield = 0;
        for (var ff = f - 1; ff <= f + 1; ff++) {
          if (ff < 0 || ff > 7) continue;
          if (pos.squares[squareOf(shieldRank, ff)] == makePiece(pawn, c)) {
            shield++;
          }
        }
        kingSafety += sign * 15 * shield;
      }
    }
  }

  return EvalTerms(
    material: material,
    center: center,
    development: development,
    kingSafety: kingSafety,
  );
}

/// Score in centipawns from the point of view of the side to move.
int evaluate(Position pos) {
  final total = evalTerms(pos).total;
  return pos.turn == white ? total : -total;
}
