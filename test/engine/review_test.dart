import 'dart:math';

import 'package:chess_solver/engine/insight.dart';
import 'package:chess_solver/engine/mistakes.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/puzzle.dart';
import 'package:chess_solver/engine/review.dart';
import 'package:chess_solver/engine/weakspots.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewEntry review(String fen, String uci) {
  final pos = Position.fromFen(fen);
  final move = pos.legalMoves().firstWhere((m) => m.uci == uci);
  return reviewMove(pos, move,
      ply: 0, mistake: explainMistake(pos, move));
}

Puzzle puzzle(String id, Idea? idea, int tier) => Puzzle(
      id: id,
      fen: Position.startFen,
      solutions: const ['e2e4'],
      san: 'e4',
      idea: idea,
      mateIn: idea == null ? 2 : 0,
      tier: tier,
      text: '',
      source: 'hand',
    );

void main() {
  test('a sound move has no mistake and no key', () {
    final e = review(Position.startFen, 'e2e4');
    expect(e.isMistake, isFalse);
    expect(e.missedKey, isNull);
    expect(e.number, '1.');
    expect(e.san, 'e4');
  });

  test('missing a back-rank mate is keyed by the mate idea', () {
    final e = review('3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'g1f1');
    expect(e.mistake!.kind, MistakeKind.missesMate);
    expect(e.missedKey, isNotNull);
    expect(Idea.values.map((i) => i.name).toSet().union({mateKey}),
        contains(e.missedKey));
  });

  test('allowing mate is a mistake but not drillable', () {
    final e = review('3r2k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1', 'b1b2');
    expect(e.mistake!.kind, MistakeKind.allowsMate);
    expect(e.missedKey, isNull);
  });

  test('black moves are numbered with an ellipsis', () {
    final e = review(
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1', 'e7e5');
    expect(e.number, '1...');
  });

  test('summary counts', () {
    expect(reviewSummary(const []), 'No moves to review yet.');
    final good = review(Position.startFen, 'e2e4');
    final bad = review('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d4');
    expect(reviewSummary([good]), 'You played 1 move, all of them sound.');
    expect(reviewSummary([good, bad]), 'You played 2 moves: 1 sound, 1 mistake.');
  });

  group('weak spots', () {
    final lib = [
      puzzle('f1', Idea.fork, 1),
      puzzle('f2', Idea.fork, 2),
      puzzle('m1', null, 4),
      puzzle('p1', Idea.pin, 3),
    ];

    test('weakest ranks by count and drops undrillable keys', () {
      final w = weakest({'fork': 2, 'mate': 3, 'castling': 9, 'pin': 0}, lib);
      expect(w.map((e) => e.key), ['mate', 'fork']);
    });

    test('next puzzle: worst spot, unsolved easiest first', () {
      final missed = {'fork': 2, 'mate': 1};
      expect(nextWeakPuzzle(lib, missed, {})!.id, 'f1');
      expect(nextWeakPuzzle(lib, missed, {'f1'})!.id, 'f2');
      expect(nextWeakPuzzle(lib, missed, {'f1'}, skipId: 'f2')!.id, 'f1');
    });

    test('everything solved: repeats within the weak spot, skipping skipId', () {
      final p = nextWeakPuzzle(lib, {'fork': 1}, {'f1', 'f2'},
          skipId: 'f1', random: Random(1));
      expect(p!.id, 'f2');
    });

    test('a drill moves to the next weak spot before repeating a puzzle', () {
      final missed = {'fork': 3, 'mate': 1};
      final all = {'f1', 'f2', 'm1'};
      expect(nextWeakPuzzle(lib, missed, all, seen: {'f1', 'f2'})!.id, 'm1');
      // Every puzzle seen: falls back to repeating rather than returning null.
      expect(
        nextWeakPuzzle(lib, missed, all, skipId: 'f1', seen: all, random: Random(1)),
        isNotNull,
      );
    });

    test('nothing weak: null', () {
      expect(nextWeakPuzzle(lib, {}, {}), isNull);
    });
  });
}
