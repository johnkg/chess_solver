import 'package:chess_solver/engine/drill.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/structure.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/lessons/drills.dart';
import 'package:chess_solver/lessons/lessons.dart';
import 'package:flutter_test/flutter_test.dart';

Drill _drill(DrillGoal goal, {int side = white, int max = 10}) => Drill(
      id: 't',
      phase: 'endgame',
      title: 't',
      task: 't',
      fen: '8/8/8/8/8/8/8/8 w - - 0 1',
      side: side,
      goal: goal,
      maxMoves: max,
      hint: 't',
    );

DrillStatus _status(Drill d, String fen, [int moves = 3]) =>
    drillStatus(d, Position.fromFen(fen), moves);

void main() {
  group('mate goal', () {
    final d = _drill(DrillGoal.mate, max: 5);
    test('checkmate of the engine is a success', () {
      expect(_status(d, 'k7/8/1K6/8/8/8/8/6Q1 b - - 0 1').over, isFalse);
      expect(_status(d, '7k/6Q1/6K1/8/8/8/8/8 b - - 0 1').state, DrillState.success);
    });
    test('stalemate and running out of moves fail', () {
      expect(_status(d, 'k7/2Q5/1K6/8/8/8/8/8 b - - 0 1').state, DrillState.failure);
      expect(_status(d, 'k7/8/1K6/8/8/8/8/6Q1 b - - 0 1', 5).state, DrillState.failure);
      expect(_status(d, 'k7/8/1K6/8/8/8/8/6Q1 b - - 0 1', 4).state, DrillState.running);
    });
    test('being mated yourself, or bare kings, fail', () {
      expect(_status(d, 'k7/8/8/8/8/8/5PPP/r5K1 w - - 0 1').state, DrillState.failure);
      expect(_status(d, '8/8/8/8/8/8/8/K1k5 w - - 0 1').state, DrillState.failure);
    });
  });

  group('promote goal', () {
    final d = _drill(DrillGoal.promote, max: 8);
    test('a safe new queen on your turn is a success', () {
      expect(_status(d, '4Q3/8/8/8/8/8/8/K6k w - - 0 1').state, DrillState.success);
      // Same position right after your move (the reply is still to come).
      expect(_status(d, '4Q3/8/8/8/8/8/8/K6k b - - 0 1').over, isFalse);
    });
    test('losing the pawn, stalemate or running out of moves fail', () {
      expect(_status(d, '8/8/8/8/8/8/8/K6k w - - 0 1').state, DrillState.failure);
      expect(_status(d, '7k/8/8/8/8/8/P7/K7 w - - 0 1', 8).state, DrillState.failure);
      expect(_status(d, '7k/8/8/8/8/8/P7/K7 w - - 0 1', 7).state, DrillState.running);
      expect(_status(d, 'k7/2Q5/1K6/8/8/8/8/8 b - - 0 1').state, DrillState.failure);
    });
    test('works for Black too', () {
      final b = _drill(DrillGoal.promote, side: black);
      expect(_status(b, 'K6k/8/8/8/8/8/8/4q3 b - - 0 1').state, DrillState.success);
    });
  });

  group('hold goal', () {
    final d = _drill(DrillGoal.hold, side: black, max: 6);
    test('stalemate, a lost pawn and surviving all count as holding', () {
      expect(_status(d, 'k7/P7/K7/8/8/8/8/8 b - - 0 1').state, DrillState.success);
      expect(_status(d, '8/8/8/4k3/8/4K3/8/8 w - - 0 1').state, DrillState.success);
      expect(_status(d, '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1', 6).state, DrillState.success);
      expect(_status(d, '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1', 5).state, DrillState.running);
    });
    test('promotion and checkmate lose', () {
      expect(_status(d, '4Q3/8/8/8/8/8/8/K6k b - - 0 1').state, DrillState.failure);
      expect(_status(d, 'k7/1Q6/1K6/8/8/8/8/8 b - - 0 1').state, DrillState.failure);
    });
  });

  group('the shipped drills', () {
    test('are well formed', () {
      expect(drills.map((d) => d.id).toSet(), hasLength(drills.length));
      final lessonIds = lessons.map((l) => l.id).toSet();
      for (final d in drills) {
        final pos = Position.fromFen(d.fen);
        expect(pos.legalMoves(), isNotEmpty, reason: d.id);
        expect(d.engineLevel, isNotNull, reason: d.id);
        expect(d.task, isNotEmpty);
        expect(d.hint, isNotEmpty);
        if (d.goal == DrillGoal.find) {
          final concept = Concept.values.byName(d.concept!);
          final got = concept.isFileConcept
              ? conceptFiles(pos, concept, d.subject).map((f) => String.fromCharCode(97 + f)).toSet()
              : conceptSquares(pos, concept, d.subject).map(squareName).toSet();
          final want = concept.isFileConcept
              ? d.answers.map((a) => a[0]).toSet()
              : d.answers.toSet();
          expect(got, want, reason: d.id);
          expect(d.answers, isNotEmpty, reason: d.id);
        } else {
          expect(d.maxMoves, inInclusiveRange(5, 60));
        }
        if (d.lesson != null) expect(lessonIds, contains(d.lesson), reason: d.id);
        expect(drillStatus(d, pos, 0).over, isFalse, reason: '${d.id} must not start finished');
      }
    });

    test('every lesson that names a drill names one that exists', () {
      final ids = drills.map((d) => d.id).toSet();
      for (final l in lessons) {
        if (l.drill != null) expect(ids, contains(l.drill), reason: l.id);
      }
    });
  });
}
