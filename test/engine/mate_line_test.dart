import 'dart:math';

import 'package:chess_solver/engine/mate_line.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Morphy's Opera Game: 16.Qb8+!! Nxb8 17.Rd8#.
  final opera = Position.fromFen('4kb1r/p2n1ppp/4q3/4p1B1/4P3/1Q6/PPP2PPP/2KR4 w k - 0 1');

  test('the queen sacrifice leads to mate in 2, a quiet move does not', () {
    final sac = opera.legalMoves().firstWhere((m) => m.uci == 'b3b8');
    final quiet = opera.legalMoves().firstWhere((m) => m.uci == 'a2a3');
    expect(leadsToMate(opera, sac, 2), isTrue);
    expect(leadsToMate(opera, sac, 1), isFalse);
    expect(leadsToMate(opera, quiet, 2), isFalse);
  });

  test('every defence still loses, and one is chosen', () {
    final sac = opera.legalMoves().firstWhere((m) => m.uci == 'b3b8');
    final after = opera.makeMove(sac);
    for (var seed = 0; seed < 10; seed++) {
      final reply = stubbornDefence(after, 1, Random(seed))!;
      expect(after.legalMoves(), contains(reply));
      expect(mateIn(after.makeMove(reply), 1), isNotNull);
    }
  });

  test('a mated side has no defence', () {
    final mated = Position.fromFen('R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1');
    expect(stubbornDefence(mated, 1), isNull);
  });
}
