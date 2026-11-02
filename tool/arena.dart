// ignore_for_file: avoid_print
// Self-play between computer levels, to check that the gaps between them match
// their target ratings.
//   dart run tool/arena.dart [games-per-pair] [time-scale] [first-pair] [last-pair] [seed] [settings.json]
// Pair i is level i+1 against level i. [time-scale] multiplies every level's
// thinking time (keeping the ratios between levels), so a short run still
// tells the top levels apart; 1 plays at the real speed. Colours alternate.
// Prints the score and the Elo gap it implies next to the target gap. With
// few games the estimate is rough: 12 games is about +-100 Elo.
// [settings.json] is a list with one object per level (depth, millis, temperature,
// margin, bookPlies, mateDepth) to try instead of the real table.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';

/// Thinking time never drops below this, whatever the time scale.
const int _minMillis = 40;

/// Longest game played; a game that long is scored as a draw.
const int _maxPlies = 240;

/// Result for White: 1 win, 0.5 draw, 0 loss.
double play(LevelSettings whiteSide, LevelSettings blackSide, Random rng, double timeScale) {
  var pos = Position.start();
  final seen = <String>[];
  for (var ply = 0; ply < _maxPlies; ply++) {
    final side = pos.turn == white ? whiteSide : blackSide;
    final millis = max(_minMillis, (side.millis * timeScale).round());
    final move = chooseMoveWith(pos, side, rng, millis, seen);
    if (move == null) {
      return pos.inCheck ? (pos.turn == white ? 0 : 1) : 0.5;
    }
    seen.add(pos.repetitionKey);
    pos = pos.makeMove(move);
    if (drawReason(pos, seen: seen) != null) return 0.5;
  }
  return 0.5;
}

/// Elo gap implied by [score] points out of [games], smoothed so that a clean
/// sweep gives a large but finite number.
double eloGap(double score, int games) {
  final p = (score + 0.5) / (games + 1);
  return -400 * log(1 / p - 1) / ln10;
}

/// The settings to play: the real level table, or the ones in [path].
List<LevelSettings> loadSettings(String? path) {
  if (path == null) return [for (final level in Level.values) level.settings];
  final list = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
  if (list.length != Level.values.length) {
    throw ArgumentError('$path needs ${Level.values.length} entries, has ${list.length}');
  }
  return [
    for (final e in list)
      LevelSettings(
        depth: e['depth'] as int,
        millis: e['millis'] as int,
        temperature: e['temperature'] as int,
        margin: e['margin'] as int,
        bookPlies: e['bookPlies'] as int,
        mateDepth: (e['mateDepth'] ?? 0) as int,
      ),
  ];
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 12;
  final timeScale = args.length > 1 ? double.parse(args[1]) : 0.3;
  final levels = Level.values;
  final first = args.length > 2 ? int.parse(args[2]) : 0;
  final last = args.length > 3 ? int.parse(args[3]) : levels.length - 2;
  final seed = args.length > 4 ? int.parse(args[4]) : 7;
  final settings = loadSettings(args.length > 5 ? args[5] : null);
  for (var i = first; i <= last && i + 1 < levels.length; i++) {
    final hi = levels[i + 1];
    final lo = levels[i];
    final rng = Random(seed + i);
    var score = 0.0;
    for (var g = 0; g < games; g++) {
      score += g.isEven
          ? play(settings[i + 1], settings[i], rng, timeScale)
          : 1 - play(settings[i], settings[i + 1], rng, timeScale);
    }
    final gap = eloGap(score, games).round();
    print('${hi.label} vs ${lo.label}: ${hi.label} scores $score / $games '
        '(${(100 * score / games).round()}%), gap about ${gap >= 0 ? '+' : ''}$gap Elo, target +${hi.elo - lo.elo}');
  }
}
