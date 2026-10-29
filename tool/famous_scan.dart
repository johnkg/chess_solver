// ignore_for_file: avoid_print
// Finds puzzle positions in the famous games: every position (either side to
// move) that rater.dart accepts as a clean puzzle. Prints one JSON object per
// puzzle, with the full rating, for tool/curate.py to add to the library.
//   python3 tool/famous.py                        (writes famous_games.json)
//   dart run tool/famous_scan.dart [part] [parts] > picks_part.jsonl
import 'dart:convert';
import 'dart:io';

import 'package:chess_solver/engine/opening_line.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/rater.dart';

void main(List<String> args) {
  final part = args.isNotEmpty ? int.parse(args[0]) : 0;
  final parts = args.length > 1 ? int.parse(args[1]) : 1;
  final games = jsonDecode(File('tool/famous_games.json').readAsStringSync()) as List;
  var job = 0;
  for (final g in games) {
    final id = g['id'] as String;
    final line = OpeningLine.fromSan([for (final s in g['sans'] as List) s as String]);
    for (var ply = 0; ply < line.length; ply++) {
      if (job++ % parts != part) continue;
      final Position pos = line.positions[ply];
      if (ply < 4) continue;
      final r = ratePuzzle(pos, maxMate: 3);
      if (r == null) continue;
      print(jsonEncode({
        'game': id,
        'ply': ply,
        'fen': pos.toFen(),
        'solutions': r.solutions,
        'san': r.san,
        'idea': r.idea?.name,
        'tier': r.tier,
        'mateIn': r.mateIn,
        'text': r.text,
      }));
    }
  }
}
