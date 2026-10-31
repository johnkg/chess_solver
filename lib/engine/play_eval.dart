import 'piece.dart';
import 'position.dart';

/// Evaluation used by the computer opponent only. The teaching text keeps
/// using the named terms in `eval.dart`; this one is tuned to pick good moves:
/// material, piece-square tables, pawn structure, bishop pair, rooks on open
/// files and king safety.

/// Material value in centipawns, indexed by piece type (the king has none).
const List<int> centipawnValue = [0, 100, 320, 330, 500, 900, 0];

// Piece-square tables, written as the board is drawn: first row is rank 8,
// from White's side. Values in centipawns.
const List<int> _pawnTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _knightTable = [
  -50, -40, -30, -30, -30, -30, -40, -50, //
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _bishopTable = [
  -20, -10, -10, -10, -10, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _rookTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _queenTable = [
  -20, -10, -10, -5, -5, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _kingMiddle = [
  -30, -40, -40, -50, -50, -40, -40, -30, //
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const List<int> _kingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];
const List<List<int>> _tables = [
  [], _pawnTable, _knightTable, _bishopTable, _rookTable, _queenTable, _kingMiddle,
];

/// Bonus for a passed pawn by how far it has advanced (relative rank 0..7).
const List<int> _passed = [0, 10, 15, 25, 45, 80, 140, 0];

/// Score in centipawns from the side to move's point of view.
int playEval(Position pos) {
  final sq = pos.squares;
  var score = 0; // White minus Black
  var nonPawn = 0;
  final pawnFiles = [List<int>.filled(8, 0), List<int>.filled(8, 0)];
  final bishops = [0, 0];
  final kings = [-1, -1];
  final rooks = <int>[];

  for (var x = 0; x < 64; x++) {
    final p = sq[x];
    if (p == empty) continue;
    final c = pieceColor(p);
    final t = pieceType(p);
    final r = rankOf(x);
    final f = fileOf(x);
    final rel = c == white ? r : 7 - r;
    final row = 7 - rel;
    final sign = c == white ? 1 : -1;
    var s = centipawnValue[t];
    if (t == king) {
      kings[c] = x;
    } else {
      s += _tables[t][row * 8 + f];
      if (t == pawn) {
        pawnFiles[c][f]++;
      } else {
        nonPawn += centipawnValue[t];
        if (t == bishop) bishops[c]++;
        if (t == rook) rooks.add(x);
      }
    }
    score += sign * s;
  }

  // King: middlegame table fades into the endgame table as pieces come off.
  final endgame = (1 - nonPawn / 6200).clamp(0.0, 1.0);
  for (var c = 0; c < 2; c++) {
    final k = kings[c];
    if (k < 0) continue;
    final rel = c == white ? rankOf(k) : 7 - rankOf(k);
    final i = (7 - rel) * 8 + fileOf(k);
    final v = (_kingMiddle[i] * (1 - endgame) + _kingEnd[i] * endgame).round();
    score += (c == white ? 1 : -1) * v;
  }

  // Pawn structure.
  for (var c = 0; c < 2; c++) {
    final sign = c == white ? 1 : -1;
    final mine = pawnFiles[c];
    for (var f = 0; f < 8; f++) {
      if (mine[f] == 0) continue;
      if (mine[f] > 1) score -= sign * 15 * (mine[f] - 1);
      final left = f > 0 ? mine[f - 1] : 0;
      final right = f < 7 ? mine[f + 1] : 0;
      if (left == 0 && right == 0) score -= sign * 12;
    }
  }
  for (var x = 0; x < 64; x++) {
    final p = sq[x];
    if (p == empty || pieceType(p) != pawn) continue;
    final c = pieceColor(p);
    if (_isPassed(sq, x, c)) {
      final rel = c == white ? rankOf(x) : 7 - rankOf(x);
      score += (c == white ? 1 : -1) * _passed[rel];
    }
  }

  // Bishop pair, rooks on open files.
  if (bishops[white] >= 2) score += 30;
  if (bishops[black] >= 2) score -= 30;
  for (final x in rooks) {
    final c = pieceColor(sq[x]);
    final f = fileOf(x);
    final own = pawnFiles[c][f];
    final opp = pawnFiles[1 - c][f];
    final bonus = own == 0 ? (opp == 0 ? 20 : 10) : 0;
    score += (c == white ? 1 : -1) * bonus;
  }

  // Pawn shield in front of a castled king (only while queens are on).
  if (endgame < 0.5) {
    for (var c = 0; c < 2; c++) {
      final k = kings[c];
      if (k < 0) continue;
      final backRank = c == white ? 0 : 7;
      if (rankOf(k) != backRank) continue;
      final dir = c == white ? 1 : -1;
      var shield = 0;
      for (var f = fileOf(k) - 1; f <= fileOf(k) + 1; f++) {
        if (f < 0 || f > 7) continue;
        if (sq[squareOf(backRank + dir, f)] == makePiece(pawn, c)) shield++;
      }
      score += (c == white ? 1 : -1) * 12 * shield;
    }
  }

  final fromMover = pos.turn == white ? score : -score;
  return fromMover + 10; // small bonus for having the move
}

bool _isPassed(List<int> sq, int x, int c) {
  final f = fileOf(x);
  final r = rankOf(x);
  final dir = c == white ? 1 : -1;
  final enemyPawn = makePiece(pawn, 1 - c);
  for (var rr = r + dir; rr >= 0 && rr < 8; rr += dir) {
    for (var ff = f - 1; ff <= f + 1; ff++) {
      if (ff < 0 || ff > 7) continue;
      if (sq[squareOf(rr, ff)] == enemyPawn) return false;
    }
  }
  return true;
}
