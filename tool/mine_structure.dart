// ignore_for_file: avoid_print
// Collects middlegame positions from quick engine self-play and prints, for
// each structure concept, positions where the concept has 1-3 targets, so
// lessons and drills can be picked by hand.
//   dart run tool/mine_structure.dart [games] [seed]
import 'dart:convert';
import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/structure.dart';

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 12;
  final rng = Random(args.length > 1 ? int.parse(args[1]) : 3);
  final seen = <String>{};
  for (var g = 0; g < games; g++) {
    var pos = Position.start();
    for (var ply = 0; ply < 90; ply++) {
      if (pos.legalMoves().isEmpty || drawReason(pos) != null) break;
      if (ply >= 16 && ply % 6 == 0 && !pos.inCheck && seen.add(pos.toFen().split(' ').first)) {
        for (final c in Concept.values) {
          for (final color in [white, black]) {
            final fileBased = c.isFileConcept;
            final sq = conceptSquares(pos, c, color);
            final n = fileBased ? conceptFiles(pos, c, color).length : sq.length;
            if (n >= 1 && n <= (fileBased ? 2 : 3)) {
              if (c == Concept.openFile && color == black) continue;
              print(jsonEncode({
                'concept': c.name,
                'color': color == white ? 'white' : 'black',
                'fen': pos.toFen(),
                'targets': [for (final s in sq) squareName(s)],
                'ply': ply,
                'game': g,
              }));
            }
          }
        }
      }
      final m = chooseMove(pos, Level.values[3 + rng.nextInt(3)], rng, 60);
      if (m == null) break;
      pos = pos.makeMove(m);
    }
  }
}
