// ignore_for_file: avoid_print
// Prints the engine's ranking of the best moves for FENs read from stdin
// (one per line). Used to author and check strategic drills.
//   dart run tool/rank.dart [depth] < fens.txt
import 'dart:io';

import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/san.dart';

void main(List<String> args) {
  final depth = args.isNotEmpty ? int.parse(args[0]) : 6;
  String? line;
  while ((line = stdin.readLineSync()) != null) {
    if (line!.trim().isEmpty || line.startsWith('#')) continue;
    final pos = Position.fromFen(line.trim());
    final r = Searcher().search(pos, maxDepth: depth, millis: 20000, margin: 120)!;
    final top = [
      for (final e in r.moves.take(5)) '${san(pos, e.$1)} (${e.$2})',
    ];
    print('${line.trim()}\n   d${r.depth}: ${top.join('  ')}');
  }
}
