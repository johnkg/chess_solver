// ignore_for_file: avoid_print
// Self-play between computer levels, to check that the gaps between them match
// their target ratings.
//   dart run tool/arena.dart [games-per-pair] [time-scale] [first-pair] [last-pair] [seed]
// Pair i is level i+1 against level i. [time-scale] multiplies every level's
// thinking time (keeping the ratios between levels), so a short run still
// tells the top levels apart; 1 plays at the real speed. Colours alternate.
// Prints the score and the Elo gap it implies next to the target gap. With
// few games the estimate is rough: 12 games is about +-100 Elo.
import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';

/// Thinking time never drops below this, whatever the time scale.
const int _minMillis = 40;

/// Longest game played; a game that long is scored as a draw.
const int _maxPlies = 240;

/// Result for White: 1 win, 0.5 draw, 0 loss.
double play(Level whiteLevel, Level blackLevel, Random rng, double timeScale) {
  var pos = Position.start();
  final seen = <String>[];
  for (var ply = 0; ply < _maxPlies; ply++) {
    final level = pos.turn == white ? whiteLevel : blackLevel;
    final millis = max(_minMillis, (level.millis * timeScale).round());
    final move = chooseMove(pos, level, rng, millis, seen);
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

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 12;
  final timeScale = args.length > 1 ? double.parse(args[1]) : 0.3;
  final levels = Level.values;
  final first = args.length > 2 ? int.parse(args[2]) : 0;
  final last = args.length > 3 ? int.parse(args[3]) : levels.length - 2;
  final seed = args.length > 4 ? int.parse(args[4]) : 7;
  for (var i = first; i <= last && i + 1 < levels.length; i++) {
    final hi = levels[i + 1];
    final lo = levels[i];
    final rng = Random(seed + i);
    var score = 0.0;
    for (var g = 0; g < games; g++) {
      score += g.isEven ? play(hi, lo, rng, timeScale) : 1 - play(lo, hi, rng, timeScale);
    }
    final gap = eloGap(score, games).round();
    print('${hi.label} vs ${lo.label}: ${hi.label} scores $score / $games '
        '(${(100 * score / games).round()}%), gap about ${gap >= 0 ? '+' : ''}$gap Elo, target +${hi.elo - lo.elo}');
  }
}
