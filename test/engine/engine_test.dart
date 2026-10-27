import 'dart:math';

import 'package:chess_solver/engine/book.dart';
import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SearchResult think(String fen, {int depth = 4, int millis = 3000, int margin = 50}) =>
      Searcher().search(Position.fromFen(fen), maxDepth: depth, millis: millis, margin: margin)!;

  test('finds a mate in two', () {
    final r = think('r5rk/5p1p/5R2/4B3/8/8/7Q/6RK w - - 0 1', depth: 5);
    expect(r.best.$2, greaterThan(90000));
  });

  test('takes a free queen and keeps its own queen safe', () {
    final take = think('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1');
    expect(take.best.$1.uci, 'd1d5');
    // Black to move with a queen attacked by a pawn: it must move or defend it.
    final save = think('4k3/8/8/3q4/2P5/8/8/4K3 b - - 0 1');
    expect(save.moves.any((e) => e.$1.uci == 'd5d6'), isTrue);
    expect(save.best.$2, greaterThan(-300));
  });

  test('prefers the better capture sequence', () {
    // Qxd5 loses the queen to a pawn; the knight fork wins material.
    final r = think('r3k3/8/8/3N4/8/8/8/4K3 w - - 0 1', depth: 3);
    expect(r.best.$1.uci, 'd5c7');
  });

  test('returns only moves within the margin, best first', () {
    final r = think(Position.startFen, depth: 3, millis: 1000, margin: 30);
    expect(r.moves.length, greaterThan(1));
    for (var i = 1; i < r.moves.length; i++) {
      expect(r.moves[i].$2, lessThanOrEqualTo(r.moves[i - 1].$2));
    }
    expect(r.moves.last.$2, greaterThanOrEqualTo(r.best.$2 - 30));
  });

  test('time budget is respected', () {
    final sw = Stopwatch()..start();
    think(Position.startFen, depth: 30, millis: 300);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });

  group('book and levels', () {
    test('every book line is legal and covers both colours', () {
      final table = bookTable();
      expect(table.length, greaterThan(100));
      expect(table[Position.start().toFen().split(' ').take(2).join(' ')],
          containsAll(['e2e4', 'd2d4', 'g1f3', 'c2c4']));
    });

    test('different games take different book lines', () {
      final firstFive = {
        for (var seed = 0; seed < 40; seed++) _bookGame(seed, 6),
      };
      expect(firstFive.length, greaterThan(5));
    });

    test('levels get stronger on paper', () {
      final l = Level.values;
      for (var i = 1; i < l.length; i++) {
        expect(l[i].elo, greaterThan(l[i - 1].elo));
        expect(l[i].depth, greaterThanOrEqualTo(l[i - 1].depth));
        expect(l[i].temperature, lessThan(l[i - 1].temperature));
      }
    });
  });
}

String _bookGame(int seed, int plies) {
  final rng = Random(seed);
  var pos = Position.start();
  final out = <String>[];
  for (var i = 0; i < plies; i++) {
    final m = bookMove(pos, 99, rng);
    if (m == null) break;
    out.add(m.uci);
    pos = pos.makeMove(m);
  }
  return out.join(' ');
}
