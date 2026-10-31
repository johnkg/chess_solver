// ignore_for_file: avoid_print
// Self-play between computer levels, to check that stronger levels win more.
//   dart run tool/arena.dart [games-per-pair] [millis-cap] [first-pair] [last-pair]
// Not a rating: it only checks the ordering of the levels.
import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';

double play(Level whiteLevel, Level blackLevel, Random rng, int cap) {
  var pos = Position.start();
  final seen = <String>[];
  for (var ply = 0; ply < 240; ply++) {
    final level = pos.turn == white ? whiteLevel : blackLevel;
    final move = chooseMove(pos, level, rng, min(level.millis, cap), seen);
    if (move == null) {
      return pos.inCheck ? (pos.turn == white ? 0 : 1) : 0.5;
    }
    seen.add(pos.repetitionKey);
    pos = pos.makeMove(move);
    if (drawReason(pos, seen: seen) != null) return 0.5;
  }
  return 0.5;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 4;
  final cap = args.length > 1 ? int.parse(args[1]) : 300;
  final first = args.length > 2 ? int.parse(args[2]) : 0;
  final rng = Random(7);
  final levels = Level.values;
  final last = args.length > 3 ? int.parse(args[3]) : levels.length - 2;
  for (var i = first; i <= last && i + 1 < levels.length; i++) {
    final hi = levels[i + 1];
    final lo = levels[i];
    var score = 0.0;
    for (var g = 0; g < games; g++) {
      score += g.isEven ? play(hi, lo, rng, cap) : 1 - play(lo, hi, rng, cap);
    }
    print('${hi.label} vs ${lo.label}: ${hi.label} scores $score / $games');
  }
}
