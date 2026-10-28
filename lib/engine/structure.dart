import 'piece.dart';
import 'position.dart';

/// Pawn-structure and square ideas of the middlegame, computed exactly from
/// the board (no search). Used by the middlegame lessons and drills.
enum Concept {
  /// A pawn with no enemy pawn in front of it on its own or an adjacent file.
  passed,

  /// A pawn with no friendly pawn on either adjacent file.
  isolated,

  /// Every pawn on a file that holds two or more of its side's pawns.
  doubled,

  /// A pawn that cannot be supported by another pawn and whose stop square is
  /// attacked by an enemy pawn.
  backward,

  /// Files with no pawns at all.
  openFile,

  /// Files with no pawn of [color] but at least one enemy pawn.
  semiOpenFile,

  /// A square on the fifth rank or beyond (from [color]'s side) that one of
  /// its pawns defends and no enemy pawn can ever attack.
  outpost,
}

extension ConceptInfo on Concept {
  /// True when the answer is a set of files rather than squares.
  bool get isFileConcept => this == Concept.openFile || this == Concept.semiOpenFile;
}

int _dir(int color) => color == white ? 1 : -1;

bool _pawn(Position p, int rank, int file, int color) =>
    rank >= 0 && rank < 8 && file >= 0 && file < 8 && p.squares[squareOf(rank, file)] == makePiece(pawn, color);

List<int> _pawns(Position p, int color) => [
      for (var s = 0; s < 64; s++)
        if (p.squares[s] == makePiece(pawn, color)) s,
    ];

int _pawnsOnFile(Position p, int file, int color) {
  var n = 0;
  for (var r = 0; r < 8; r++) {
    if (_pawn(p, r, file, color)) n++;
  }
  return n;
}

/// Files (0 = a) that hold no pawn at all.
List<int> openFiles(Position pos) => [
      for (var f = 0; f < 8; f++)
        if (_pawnsOnFile(pos, f, white) + _pawnsOnFile(pos, f, black) == 0) f,
    ];

/// Files with no pawn of [color] but an enemy pawn.
List<int> semiOpenFiles(Position pos, int color) => [
      for (var f = 0; f < 8; f++)
        if (_pawnsOnFile(pos, f, color) == 0 && _pawnsOnFile(pos, f, 1 - color) > 0) f,
    ];

bool _isPassed(Position p, int sq, int color) {
  final f = fileOf(sq);
  for (var r = rankOf(sq) + _dir(color); r >= 0 && r < 8; r += _dir(color)) {
    for (var ff = f - 1; ff <= f + 1; ff++) {
      if (_pawn(p, r, ff, 1 - color)) return false;
    }
  }
  return true;
}

bool _isIsolated(Position p, int sq, int color) {
  final f = fileOf(sq);
  return (f == 0 || _pawnsOnFile(p, f - 1, color) == 0) &&
      (f == 7 || _pawnsOnFile(p, f + 1, color) == 0);
}

bool _isBackward(Position p, int sq, int color) {
  final f = fileOf(sq);
  final r = rankOf(sq);
  final dir = _dir(color);
  var neighbours = 0;
  for (final ff in [f - 1, f + 1]) {
    for (var rr = 0; rr < 8; rr++) {
      if (!_pawn(p, rr, ff, color)) continue;
      neighbours++;
      // A neighbour level with or behind this pawn can still support it.
      if ((rr - r) * dir <= 0) return false;
    }
  }
  if (neighbours == 0) return false; // isolated, not backward
  final stop = r + dir;
  if (stop < 0 || stop > 7) return false;
  // The stop square is attacked by an enemy pawn.
  return _pawn(p, stop + dir, f - 1, 1 - color) || _pawn(p, stop + dir, f + 1, 1 - color);
}

/// Squares that show [concept] for [color]'s side. For file concepts every
/// square of each file is listed (for highlighting); use [conceptFiles] to
/// compare answers.
List<int> conceptSquares(Position pos, Concept concept, int color) {
  switch (concept) {
    case Concept.passed:
      return [for (final s in _pawns(pos, color)) if (_isPassed(pos, s, color)) s];
    case Concept.isolated:
      return [for (final s in _pawns(pos, color)) if (_isIsolated(pos, s, color)) s];
    case Concept.doubled:
      return [
        for (final s in _pawns(pos, color))
          if (_pawnsOnFile(pos, fileOf(s), color) >= 2) s,
      ];
    case Concept.backward:
      return [for (final s in _pawns(pos, color)) if (_isBackward(pos, s, color)) s];
    case Concept.openFile:
      return [for (final f in openFiles(pos)) for (var r = 0; r < 8; r++) squareOf(r, f)];
    case Concept.semiOpenFile:
      return [for (final f in semiOpenFiles(pos, color)) for (var r = 0; r < 8; r++) squareOf(r, f)];
    case Concept.outpost:
      return _outposts(pos, color);
  }
}

/// The files of a file concept, or the files of the squares otherwise.
Set<int> conceptFiles(Position pos, Concept concept, int color) => switch (concept) {
      Concept.openFile => openFiles(pos).toSet(),
      Concept.semiOpenFile => semiOpenFiles(pos, color).toSet(),
      _ => {for (final s in conceptSquares(pos, concept, color)) fileOf(s)},
    };

List<int> _outposts(Position pos, int color) {
  final dir = _dir(color);
  final out = <int>[];
  for (var r = 0; r < 8; r++) {
    final relative = color == white ? r : 7 - r;
    if (relative < 4 || relative > 6) continue;
    for (var f = 0; f < 8; f++) {
      final occupant = pos.squares[squareOf(r, f)];
      if (occupant != empty && (pieceColor(occupant) != color || pieceType(occupant) == pawn)) continue;
      final defended = _pawn(pos, r - dir, f - 1, color) || _pawn(pos, r - dir, f + 1, color);
      if (!defended) continue;
      var attackable = false;
      for (final ff in [f - 1, f + 1]) {
        for (var rr = r + dir; rr >= 0 && rr < 8; rr += dir) {
          if (_pawn(pos, rr, ff, 1 - color)) attackable = true;
        }
      }
      if (!attackable) out.add(squareOf(r, f));
    }
  }
  return out;
}
