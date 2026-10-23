import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perft counts from the Chess Programming Wiki. If move generation has
/// any bug (castling, en passant, promotion, pins), one of these breaks.
void main() {
  void check(String name, String fen, List<int> expected) {
    test('perft $name', () {
      final pos = Position.fromFen(fen);
      for (var i = 0; i < expected.length; i++) {
        expect(pos.perft(i + 1), expected[i], reason: '$name depth ${i + 1}');
      }
    });
  }

  check('start position', Position.startFen, [20, 400, 8902, 197281]);

  check(
    'kiwipete',
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    [48, 2039, 97862],
  );

  check(
    'position 3 (en passant, pins)',
    '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    [14, 191, 2812, 43238],
  );

  check(
    'position 4 (promotions, castling)',
    'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
    [6, 264, 9467],
  );

  check(
    'position 5',
    'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
    [44, 1486, 62379],
  );
}
