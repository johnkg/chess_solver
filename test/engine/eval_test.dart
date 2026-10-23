import 'package:chess_solver/engine/eval.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_mirror.py, whose logic was verified in Python.
void main() {
  test('start position is balanced in every term', () {
    final t = evalTerms(Position.start());
    expect(t.toMap().values.every((v) => v == 0), isTrue, reason: '$t');
  });

  test('1.e4 raises the center term', () {
    final pos = Position.fromFen(
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    expect(evalTerms(pos).center, 30);
  });

  test('1.Nf3 improves development', () {
    final pos = Position.fromFen(
        'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1');
    expect(evalTerms(pos).development, 15);
  });

  test('extra queen is +900 material', () {
    final pos = Position.fromFen('4k3/8/8/8/8/8/8/3QK3 w - - 0 1');
    expect(evalTerms(pos).material, 900);
  });

  test('evaluate flips sign with the side to move', () {
    final w = Position.fromFen('4k3/8/8/8/8/8/8/3QK3 w - - 0 1');
    final b = Position.fromFen('4k3/8/8/8/8/8/8/3QK3 b - - 0 1');
    expect(evaluate(w), -evaluate(b));
  });

  test('evaluation is colour symmetric', () {
    final white = Position.fromFen('4k3/8/8/8/8/8/8/3QK3 w - - 0 1');
    final black = Position.fromFen('3qk3/8/8/8/8/8/8/4K3 b - - 0 1');
    expect(evaluate(white), evaluate(black));
  });

  test('diff shows which terms a move changed', () {
    final before = Position.start();
    final after = Position.fromFen(
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    final d = evalTerms(after) - evalTerms(before);
    expect(d.center, 30);
    expect(d.material, 0);
  });
}
