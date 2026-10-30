import 'dart:math';

import 'package:chess_solver/engine/achievements.dart';
import 'package:chess_solver/engine/puzzle.dart';
import 'package:chess_solver/engine/repertoire.dart';
import 'package:chess_solver/engine/review.dart';
import 'package:chess_solver/engine/rush.dart';
import 'package:chess_solver/engine/srs.dart';
import 'package:flutter_test/flutter_test.dart';

Puzzle puzzle(String id, int tier, {int mateIn = 0}) => Puzzle(
      id: id,
      fen: '4k3/8/8/8/8/8/8/4K3 w - - 0 1',
      solutions: const ['e1e2'],
      san: 'Ke2',
      idea: null,
      mateIn: mateIn,
      tier: tier,
      text: '',
      source: 'hand',
    );

void main() {
  group('spaced repetition', () {
    test('a miss comes back tomorrow', () {
      final c = afterReview(null, correct: false, today: 100)!;
      expect(c.box, 0);
      expect(c.due, 101);
    });

    test('clean solves move up the boxes and finally graduate', () {
      var c = afterReview(null, correct: false, today: 0);
      final dues = <int>[];
      var day = 1;
      while (c != null) {
        dues.add(c.due);
        day = c.due;
        c = afterReview(c, correct: true, today: day);
      }
      expect(dues, [1, 4, 11, 25, 55]);
    });

    test('a miss while learning starts over', () {
      final c = afterReview(const SrsCard(box: 3, due: 50), correct: false, today: 60)!;
      expect(c.box, 0);
      expect(c.due, 61);
    });

    test('a clean solve of an untracked puzzle stays untracked', () {
      expect(afterReview(null, correct: true, today: 5), isNull);
    });

    test('dueIds lists overdue cards first', () {
      final ids = dueIds({
        'b': const SrsCard(box: 1, due: 9),
        'a': const SrsCard(box: 0, due: 10),
        'c': const SrsCard(box: 2, due: 20),
        'd': const SrsCard(box: 0, due: 3),
      }, 10);
      expect(ids, ['d', 'b', 'a']);
    });

    test('cards survive encoding, including ids with colons', () {
      final text = const SrsCard(box: 2, due: 77).encode('mate2-5');
      final (id, card) = SrsCard.decode(text)!;
      expect(id, 'mate2-5');
      expect(card.box, 2);
      expect(card.due, 77);
      expect(SrsCard.decode('junk'), isNull);
      expect(SrsCard.decode('x:9:1'), isNull);
    });
  });

  group('puzzle rush', () {
    test('only single-move puzzles are used', () {
      final pool = rushPool([puzzle('a', 1), puzzle('b', 2, mateIn: 1), puzzle('c', 3, mateIn: 2)]);
      expect(pool.map((p) => p.id), ['a', 'b']);
    });

    test('difficulty rises every three solved', () {
      expect([for (var s = 0; s < 9; s += 2) rushTier(s)], [1, 1, 2, 3, 3]);
    });

    test('picks the wanted tier, then the nearest, and avoids repeats', () {
      final pool = [puzzle('a', 1), puzzle('b', 1), puzzle('c', 3)];
      final rng = Random(1);
      expect(nextRushPuzzle(pool, 0, {}, random: rng)!.tier, 1);
      expect(nextRushPuzzle(pool, 0, {'a'}, random: rng)!.id, 'b');
      expect(nextRushPuzzle(pool, 0, {'a', 'b'}, random: rng)!.id, 'c');
      expect(nextRushPuzzle(pool, 6, {}, random: rng)!.id, 'c');
      expect(nextRushPuzzle(pool, 0, {'a', 'b', 'c'}, random: rng), isNotNull);
      expect(nextRushPuzzle(const [], 0, {}), isNull);
    });

    test('the training path serves the easiest unsolved puzzle', () {
      final lib = [puzzle('c', 3), puzzle('a', 1), puzzle('b', 1), puzzle('d', 2)];
      expect(nextPathPuzzle(lib, {})!.id, 'a');
      expect(nextPathPuzzle(lib, {'a', 'b'})!.id, 'd');
      expect(nextPathPuzzle(lib, {'a', 'b', 'c', 'd'}), isNull);
      expect(nextPathPuzzle(lib, {}, only: (p) => p.tier == 3)!.id, 'c');
    });
  });

  group('badges', () {
    test('progress bars fill and badges are earned at the target', () {
      final none = badgesFor(const ProgressStats());
      expect(none.every((b) => !b.earned), isTrue);
      final some = badgesFor(const ProgressStats(puzzlesSolved: 30, wins: 1, peakRating: 1250));
      Achievement byId(String id) => some.firstWhere((b) => b.id == id);
      expect(byId('first-puzzle').earned, isTrue);
      expect(byId('puzzles-25').earned, isTrue);
      expect(byId('puzzles-100').earned, isFalse);
      expect(byId('puzzles-100').fraction, closeTo(0.3, 1e-9));
      expect(byId('first-win').earned, isTrue);
      expect(byId('rating-1200').earned, isTrue);
      expect(byId('rating-1400').earned, isFalse);
      expect(some.map((b) => b.id).toSet().length, some.length);
    });
  });

  group('repertoire', () {
    final tree = Repertoire.fromLines([
      'e4 e5 Nf3 Nc6 Bb5 a6'.split(' '),
      'e4 e5 Nf3 Nc6 Bb5 Nf6'.split(' '),
      'e4 e5 Nf3 d6'.split(' '),
    ], ['Main', 'Berlin', 'Philidor']);

    test('lines share their moves and branch where they differ', () {
      var n = tree.root;
      for (final s in ['e4', 'e5', 'Nf3']) {
        expect(n.children.length, 1);
        n = n.children.first;
        expect(n.san, s);
      }
      expect(n.children.map((c) => c.san), ['Nc6', 'd6']);
      expect(n.children.last.name, 'Philidor');
      final bb5 = n.children.first.children.first;
      expect(bb5.children.map((c) => c.san), ['a6', 'Nf6']);
      expect(bb5.children.last.name, 'Berlin');
      expect(bb5.children.first.name, isNull);
      expect(tree.lineOf(bb5.children.last), 1);
      expect(tree.lineCount, 3);
    });

    test('the reply favours lines not done yet', () {
      final nf3 = tree.root.children.first.children.first.children.first;
      final rng = Random(3);
      final picks = {for (var i = 0; i < 40; i++) tree.pickReply(nf3, {0, 1}, rng).san};
      expect(picks.contains('d6'), isTrue);
      var d6 = 0;
      for (var i = 0; i < 200; i++) {
        if (tree.pickReply(nf3, {0, 1}, rng).san == 'd6') d6++;
      }
      expect(d6, greaterThan(120));
    });

    test('bad lines are rejected', () {
      expect(() => Repertoire.fromLines([['e4', 'e4']], ['x']), throwsFormatException);
      expect(() => Repertoire.fromLines([['e4', 'e5'], ['e4', 'e5']], ['a', 'b']), throwsFormatException);
      expect(() => Repertoire.fromLines([['e4', 'e5'], ['e4']], ['a', 'b']), throwsFormatException);
      expect(() => Repertoire.fromLines([['e4'], ['e4', 'e5']], ['a', 'b']), throwsFormatException);
    });
  });

  test('accuracy of no moves is unknown', () {
    expect(reviewAccuracy(const []), isNull);
  });
}
