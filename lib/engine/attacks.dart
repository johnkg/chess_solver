import 'dart:math' as math;

import 'move.dart';
import 'piece.dart';
import 'position.dart';

const List<List<int>> kKnightSteps = [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2], //
];
const List<List<int>> kKingSteps = [
  [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1], //
];
const List<List<int>> kBishopDirs = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];
const List<List<int>> kRookDirs = [
  [1, 0], [-1, 0], [0, 1], [0, -1], //
];

/// Value used when reasoning about attacks and trades, in centipawns.
/// The king is priceless.
int attackValue(int type) => type == king ? 1000 : pieceValue(type) * 100;

/// Squares of colour [by] pieces attacking [target] on [board] (a 64-entry
/// list). Pins are ignored. Order: pawns, knights, king, diagonal sliders,
/// straight sliders.
List<int> attackersOnBoard(List<int> board, int target, int by) {
  final out = <int>[];
  final r = rankOf(target);
  final f = fileOf(target);

  final pr = by == white ? r - 1 : r + 1;
  if (pr >= 0 && pr < 8) {
    for (final df in const [-1, 1]) {
      final ff = f + df;
      if (ff >= 0 && ff < 8 && board[squareOf(pr, ff)] == makePiece(pawn, by)) {
        out.add(squareOf(pr, ff));
      }
    }
  }

  void steps(List<List<int>> deltas, int piece) {
    for (final d in deltas) {
      final nr = r + d[0];
      final nf = f + d[1];
      if (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        if (board[squareOf(nr, nf)] == piece) out.add(squareOf(nr, nf));
      }
    }
  }

  void rays(List<List<int>> dirs, int a, int b) {
    for (final d in dirs) {
      var nr = r + d[0];
      var nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final p = board[squareOf(nr, nf)];
        if (p != empty) {
          if (p == a || p == b) out.add(squareOf(nr, nf));
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
  }

  steps(kKnightSteps, makePiece(knight, by));
  steps(kKingSteps, makePiece(king, by));
  rays(kBishopDirs, makePiece(bishop, by), makePiece(queen, by));
  rays(kRookDirs, makePiece(rook, by), makePiece(queen, by));
  return out;
}

List<int> attackersOf(Position pos, int target, int by) =>
    attackersOnBoard(pos.squares, target, by);

/// Squares the piece on [x] attacks, including squares holding any piece.
List<int> attackedSquares(Position pos, int x) {
  final p = pos.squares[x];
  final ty = pieceType(p);
  final c = pieceColor(p);
  final r = rankOf(x);
  final f = fileOf(x);
  final out = <int>[];

  if (ty == pawn) {
    final nr = r + (c == white ? 1 : -1);
    for (final df in const [-1, 1]) {
      if (nr >= 0 && nr < 8 && f + df >= 0 && f + df < 8) {
        out.add(squareOf(nr, f + df));
      }
    }
  } else if (ty == knight || ty == king) {
    for (final d in (ty == knight ? kKnightSteps : kKingSteps)) {
      final nr = r + d[0];
      final nf = f + d[1];
      if (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) out.add(squareOf(nr, nf));
    }
  } else {
    final dirs = ty == bishop
        ? kBishopDirs
        : ty == rook
            ? kRookDirs
            : [...kBishopDirs, ...kRookDirs];
    for (final d in dirs) {
      var nr = r + d[0];
      var nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        out.add(squareOf(nr, nf));
        if (pos.squares[squareOf(nr, nf)] != empty) break;
        nr += d[0];
        nf += d[1];
      }
    }
  }
  return out;
}

/// Can the piece of [color] on [x] be taken at a profit?
bool isSafe(Position pos, int x, int color) {
  final p = pos.squares[x];
  final atk = attackersOf(pos, x, 1 - color);
  if (atk.isEmpty) return true;
  if (attackersOf(pos, x, color).isEmpty) return false; // attacked, undefended

  int? lowest;
  for (final a in atk) {
    final t = pieceType(pos.squares[a]);
    if (t == king) continue; // a king cannot take a defended piece
    final v = attackValue(t);
    if (lowest == null || v < lowest) lowest = v;
  }
  return lowest == null || lowest >= attackValue(pieceType(p));
}

/// Net material (centipawns) the mover wins by the capture sequence on
/// `m.to`. Standard swap algorithm; the board is mutated as pieces are
/// exchanged, so x-ray attackers are found.
int seeCapture(Position pos, Move m) {
  final victim = pos.squares[m.to];
  final vv = victim != empty ? attackValue(pieceType(victim)) : 100; // e.p.
  final board = List<int>.from(pos.squares);
  final mover = board[m.from];
  board[m.from] = empty;
  board[m.to] = mover;

  final gain = <int>[vv];
  var piece = attackValue(pieceType(mover));
  var side = 1 - pos.turn;
  while (true) {
    final atk = attackersOnBoard(board, m.to, side);
    if (atk.isEmpty) break;
    var a = atk.first;
    for (final x in atk) {
      if (attackValue(pieceType(board[x])) < attackValue(pieceType(board[a]))) {
        a = x;
      }
    }
    if (pieceType(board[a]) == king &&
        attackersOnBoard(board, m.to, 1 - side).isNotEmpty) {
      break; // the king may not capture onto a defended square
    }
    gain.add(piece - gain.last);
    piece = attackValue(pieceType(board[a]));
    board[m.to] = board[a];
    board[a] = empty;
    side = 1 - side;
  }
  while (gain.length > 1) {
    final g = gain.removeLast();
    gain[gain.length - 1] = -math.max(-gain.last, g);
  }
  return gain[0];
}
