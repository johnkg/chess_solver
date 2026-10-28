// Plays every training drill with the engine in the player's seat, to see
// whether the move limits are fair.  dart run tool/drill_sim.dart [ms] [games]
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:chess_solver/engine/drill.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/lessons/drills.dart';

void main(List<String> args) {
  final ms = args.isNotEmpty ? int.parse(args[0]) : 200;
  final games = args.length > 1 ? int.parse(args[1]) : 2;
  for (final d in drills.where((d) => args.length < 3 || d.id == args[2])) {
    var wins = 0;
    var last = '';
    for (var g = 0; g < games; g++) {
      final rng = Random(g + 1);
      var pos = Position.fromFen(d.fen);
      var userMoves = 0;
      var status = drillStatus(d, pos, 0);
      var guard = 0;
      while (!status.over && guard++ < 400) {
        final mine = pos.turn == d.side;
        final m = chooseMove(pos, mine ? Level.master : d.engineLevel, rng, ms);
        if (m == null) break;
        pos = pos.makeMove(m);
        if (mine) userMoves++;
        status = drillStatus(d, pos, userMoves);
      }
      if (status.state == DrillState.success) wins++;
      last = '${status.message} after $userMoves moves';
    }
    print('${d.id.padRight(14)} $wins/$games  last: $last');
  }
}
