// ignore_for_file: avoid_print
// Mines quiet middlegame / endgame positions from engine self-play where the
// engine's best move is clearly better than every other and shows one named
// strategic idea (rook to an open file, knight on an outpost, rook on the
// seventh, passed pawn, active king). Output: one JSON object per line.
//   dart run tool/mine_middlegame.dart [games] [seed] > mined.jsonl
import 'dart:convert';
import 'dart:math';

import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/move.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/san.dart';

int rel(int sq, int color) => color == white ? rankOf(sq) : 7 - rankOf(sq);

int pawnsOnFile(Position p, int file, int color) {
  var n = 0;
  for (var r = 0; r < 8; r++) {
    if (p.squares[squareOf(r, file)] == makePiece(pawn, color)) n++;
  }
  return n;
}

bool isPassed(Position p, int sq, int color) {
  final f = fileOf(sq);
  final r = rankOf(sq);
  final dir = color == white ? 1 : -1;
  for (var rr = r + dir; rr >= 0 && rr < 8; rr += dir) {
    for (var ff = f - 1; ff <= f + 1; ff++) {
      if (ff < 0 || ff > 7) continue;
      if (p.squares[squareOf(rr, ff)] == makePiece(pawn, 1 - color)) return false;
    }
  }
  return true;
}

/// (theme, detail) for a quiet best move, or null.
(String, String)? theme(Position pos, Move m) {
  final color = pos.turn;
  final piece = pos.squares[m.from];
  final type = pieceType(piece);
  if (pos.squares[m.to] != empty || m.flag != Move.quiet && m.flag != Move.doublePush) return null;
  if (m.promotion != 0) return null;
  final after = pos.makeMove(m);
  if (after.inCheck) return null;
  final f = fileOf(m.to);
  final r = rel(m.to, color);
  final letter = String.fromCharCode(97 + f);

  if (type == rook) {
    var enemyKingOn8 = false;
    var enemyPawnsOn7 = 0;
    for (var ff = 0; ff < 8; ff++) {
      final k = pos.squares[squareOf(color == white ? 7 : 0, ff)];
      if (k == makePiece(king, 1 - color)) enemyKingOn8 = true;
      if (pos.squares[squareOf(color == white ? 6 : 1, ff)] == makePiece(pawn, 1 - color)) enemyPawnsOn7++;
    }
    if (r == 6 && rel(m.from, color) != 6 && (enemyKingOn8 || enemyPawnsOn7 >= 2)) {
      return ('seventh', enemyKingOn8 ? 'king' : 'pawns');
    }
    if (fileOf(m.from) != f) {
      final own = pawnsOnFile(pos, f, color);
      final opp = pawnsOnFile(pos, f, 1 - color);
      final fromOwn = pawnsOnFile(pos, fileOf(m.from), color);
      if (own == 0 && opp == 0 && fromOwn > 0) return ('openFile', 'open:$letter');
      if (own == 0 && opp > 0 && fromOwn > 0) return ('openFile', 'semi:$letter');
    }
  }
  if (type == knight && r >= 4) {
    final dir = color == white ? 1 : -1;
    final rank = rankOf(m.to);
    var supported = false;
    for (final df in [-1, 1]) {
      final pf = f + df;
      if (pf < 0 || pf > 7) continue;
      final pr = rank - dir;
      if (pr >= 0 && pr < 8 && pos.squares[squareOf(pr, pf)] == makePiece(pawn, color)) supported = true;
    }
    var attackable = false;
    for (final df in [-1, 1]) {
      final pf = f + df;
      if (pf < 0 || pf > 7) continue;
      for (var rr = rank + dir; rr >= 0 && rr < 8; rr += dir) {
        if (pos.squares[squareOf(rr, pf)] == makePiece(pawn, 1 - color)) attackable = true;
      }
    }
    if (supported && !attackable) return ('outpost', squareName(m.to));
  }
  if (type == pawn && r >= 4 && isPassed(after, m.to, color)) {
    if (!isPassed(pos, m.from, color) || m.flag == Move.doublePush) return ('passedPawn', squareName(m.to));
    return ('passedPawn', squareName(m.to));
  }
  if (type == king) {
    var queens = 0;
    var pieces = 0;
    for (final p in pos.squares) {
      if (p == empty) continue;
      final t = pieceType(p);
      if (t == queen) queens++;
      if (t != pawn && t != king) pieces++;
    }
    if (queens == 0 && pieces <= 4) {
      int dist(int sq) {
        final df = (fileOf(sq) - 3.5).abs();
        final dr = (rankOf(sq) - 3.5).abs();
        return max(df, dr).round();
      }
      if (dist(m.to) < dist(m.from)) return ('kingActivity', squareName(m.to));
    }
  }
  return null;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 6;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  final rng = Random(seed);
  final seen = <String>{};
  final levels = [Level.club, Level.advanced, Level.expert];
  for (var g = 0; g < games; g++) {
    var pos = Position.start();
    final a = levels[rng.nextInt(levels.length)];
    final b = levels[rng.nextInt(levels.length)];
    for (var ply = 0; ply < 110; ply++) {
      final legal = pos.legalMoves();
      if (legal.isEmpty || drawReason(pos) != null) break;
      if (ply >= 12 && !pos.inCheck) {
        final quick = Searcher().search(pos, maxDepth: 4, millis: 600, margin: 300)!;
        final best = quick.best;
        final t = theme(pos, best.$1);
        if (t != null && best.$2.abs() < 300) {
          final deep = Searcher().search(pos, maxDepth: 7, millis: 6000, margin: 300)!;
          final d5 = Searcher().search(pos, maxDepth: 5, millis: 20000, margin: 300)!;
          final top = deep.best;
          final second = deep.moves.length > 1 ? deep.moves[1].$2 : null;
          final unique = second == null || top.$2 - second >= 60;
          final unique5 = d5.moves.length < 2 || d5.best.$2 - d5.moves[1].$2 >= 40;
          final key = pos.toFen().split(' ').first;
          if (top.$1 == best.$1 && d5.best.$1 == best.$1 && unique && unique5 && top.$2.abs() < 300 && seen.add(key)) {
            final t2 = theme(pos, top.$1);
            if (t2 != null) {
              print(jsonEncode({
                'fen': pos.toFen(),
                'uci': top.$1.uci,
                'san': san(pos, top.$1),
                'theme': t2.$1,
                'detail': t2.$2,
                'score': top.$2,
                'second': second,
                'game': g,
                'ply': ply,
              }));
            }
          }
        }
      }
      final lvl = pos.turn == white ? a : b;
      final m = chooseMove(pos, lvl, rng, 120);
      if (m == null) break;
      pos = pos.makeMove(m);
    }
  }
}
