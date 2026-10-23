import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_mirror.py, whose logic was verified in Python.
void main() {
  group('mate in N', () {
    final cases = <(String, String, String)>[
      ('back rank', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1', 'a1a8'),
      (
        "scholar's mate",
        'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
        'h5f7',
      ),
      ('rook and king', '7k/8/6K1/8/8/8/8/R7 w - - 0 1', 'a1a8'),
    ];
    for (final (name, fen, uci) in cases) {
      test('finds $name', () {
        final pos = Position.fromFen(fen);
        final mate = findMate(pos, 2);
        expect(mate, isNotNull);
        expect(mate!.moves, 1);
        expect(mate.move.uci, uci);
        expect(pos.makeMove(mate.move).isCheckmate, isTrue);
      });
    }

    test('start position has no mate in 2', () {
      expect(findMate(Position.start(), 2), isNull);
    });

    test('queen and king finds a real mate, never stalemate', () {
      final pos = Position.fromFen('k7/8/1K6/8/8/8/8/6Q1 w - - 0 1');
      final mate = findMate(pos, 1);
      expect(mate, isNotNull);
      expect(pos.makeMove(mate!.move).isCheckmate, isTrue);
    });
  });

  group('alpha-beta', () {
    test('takes the hanging queen', () {
      final pos = Position.fromFen('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1');
      final best = bestMove(pos, 2)!;
      expect(best.move.uci, 'd1d5');
      expect(best.score, greaterThanOrEqualTo(400));
    });

    test('finds back-rank mate and scores it as mate', () {
      final pos = Position.fromFen('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1');
      final best = bestMove(pos, 2)!;
      expect(best.move.uci, 'a1a8');
      expect(isMateScore(best.score), isTrue);
    });

    test('no legal moves gives null', () {
      final mated = Position.fromFen('R5k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1');
      expect(bestMove(mated, 2), isNull);
    });
  });
}
