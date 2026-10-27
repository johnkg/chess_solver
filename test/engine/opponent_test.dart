import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every level plays a legal move from the start', () {
    final pos = Position.start();
    final legal = pos.legalMoves().map((m) => m.uci).toSet();
    for (final l in Level.values) {
      expect(legal, contains(chooseMove(pos, l, Random(1), 60)!.uci));
    }
  });

  test('every level plays a mate in one', () {
    final pos = Position.fromFen('6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1');
    for (final l in Level.values) {
      expect(chooseMove(pos, l, Random(2), 60)!.uci, 'a1a8');
    }
  });

  test('club level takes a free queen', () {
    final pos = Position.fromFen('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1');
    expect(chooseMove(pos, Level.club, Random(3), 200)!.uci, 'd1d5');
  });

  test('openings vary: not one fixed reply at any level', () {
    final replyTo = {
      'start': Position.start(),
      'e4': Position.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1'),
    };
    for (final l in Level.values) {
      for (final pos in replyTo.values) {
        final moves = {
          for (var seed = 0; seed < 40; seed++) chooseMove(pos, l, Random(seed), 60)!.uci,
        };
        expect(moves.length, greaterThan(1), reason: '${l.label} ${pos.toFen()}');
      }
    }
  });

  test('first move is not always a knight', () {
    for (final l in Level.values) {
      final firsts = {
        for (var seed = 0; seed < 60; seed++)
          chooseMove(Position.start(), l, Random(seed), 60)!.uci,
      };
      expect(firsts.length, greaterThan(2), reason: l.label);
      expect(firsts, containsAll(['e2e4', 'd2d4']));
    }
  });

  test('no move when mated', () {
    final pos = Position.fromFen('R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1');
    expect(chooseMove(pos, Level.club), isNull);
  });

  test('drawReason', () {
    expect(drawReason(Position.start()), isNull);
    expect(drawReason(Position.fromFen('8/8/4k3/8/8/4K3/8/8 w - - 0 1')), isNotNull);
    expect(drawReason(Position.fromFen('8/8/4k3/8/8/4KB2/8/8 w - - 0 1')), isNotNull);
    expect(drawReason(Position.fromFen('8/8/4k3/8/8/4KR2/8/8 w - - 0 1')), isNull);
    expect(drawReason(Position.fromFen('8/8/4k3/8/8/4KR2/8/8 w - - 100 80')), isNotNull);
  });
}
