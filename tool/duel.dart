// ignore_for_file: avoid_print
// Same level and thinking time, transposition table on against off.
//   dart run tool/duel.dart [games] [level-index] [millis]
// Prints the score of the table side. Colours alternate; the opening is
// randomised by playing a few random legal moves first.
import 'dart:math';

import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';

double play(bool tableIsWhite, Level level, int millis, Random rng) {
  var pos = Position.start();
  final seen = <String>[];
  for (var i = 0; i < 6; i++) {
    final moves = pos.legalMoves();
    seen.add(pos.repetitionKey);
    pos = pos.makeMove(moves[rng.nextInt(moves.length)]);
  }
  for (var ply = 0; ply < 300; ply++) {
    final useTable = (pos.turn == white) == tableIsWhite;
    final result = Searcher(useTable: useTable).search(
      pos,
      maxDepth: level.depth,
      millis: millis,
      margin: 0,
      history: seen,
    );
    if (result == null) {
      final mated = pos.inCheck;
      if (!mated) return 0.5;
      return useTable ? 0.0 : 1.0; // side to move is mated
    }
    seen.add(pos.repetitionKey);
    pos = pos.makeMove(result.best.$1);
    if (drawReason(pos, seen: seen) != null) return 0.5;
  }
  return 0.5;
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 10;
  final level = Level.values[args.length > 1 ? int.parse(args[1]) : 6];
  final millis = args.length > 2 ? int.parse(args[2]) : level.millis;
  final rng = Random(11);
  var score = 0.0;
  for (var g = 0; g < games; g++) {
    // Same random opening for both colours: reuse the seed per pair.
    final r = play(g.isEven, level, millis, Random(100 + g ~/ 2));
    score += r;
    print('game ${g + 1}: table scores $r (running $score / ${g + 1})');
  }
  print('${level.label} @ ${millis}ms: table side $score / $games');
  rng.nextInt(1);
}
