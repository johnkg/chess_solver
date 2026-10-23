import 'package:chess_solver/engine/insight.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/rater.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_rater.py, whose logic was verified in Python.
void main() {
  PuzzleRating? rateFen(String fen) => ratePuzzle(Position.fromFen(fen));

  final cases = <(String, String, String, Idea, int, int)>[
    (
      'back-rank mate in 1',
      '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
      'a1a8',
      Idea.backRankMate,
      2,
      1,
    ),
    (
      "scholar's mate",
      'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
      'h5f7',
      Idea.checkmate,
      1,
      1,
    ),
    (
      'smothered mate',
      '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1',
      'g5f7',
      Idea.smotheredMate,
      3,
      1,
    ),
    (
      'free queen',
      '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1',
      'd1d5',
      Idea.hangingPiece,
      1,
      0,
    ),
    (
      'knight fork',
      '3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1',
      'e5f7',
      Idea.fork,
      2,
      0,
    ),
  ];

  for (final (name, fen, sol, idea, tier, mate) in cases) {
    test(name, () {
      final r = rateFen(fen);
      expect(r, isNotNull);
      expect(r!.solutions.first, sol);
      expect(r.idea, idea);
      expect(r.tier, tier);
      expect(r.mateIn, mate);
    });
  }

  test('a mating move that also skewers is rated as a mate', () {
    final r = rateFen(
        'r2q1bn1/4p1pr/np1pb2p/p4k2/P2Q3P/2N1BP2/1PP1B1PR/R3K1N1 w - - 0 1');
    expect(r, isNotNull);
    expect(r!.idea, Idea.checkmate);
    expect(r.tier, 1);
  });

  test('a puzzle whose idea explains only a fraction of the win is rejected',
      () {
    // Qxa8 wins a rook, but the detectors only credit a small fork.
    expect(
      ratePuzzle(
        Position.fromFen(
            'rn3bnr/p2pkp1p/b3p1p1/1pp3N1/1P3P1P/P1N1PQ2/R1PP2P1/2B1KBR1 w - - 0 1'),
        maxMate: 1,
      ),
      isNull,
    );
  });

  test('no puzzle when several moves win the queen', () {
    // Bxa8+, Bd5+ and Bc6+ are all discovered checks that win the queen.
    expect(rateFen('q3k3/8/8/8/4B3/8/8/4R1K1 w - - 0 1'), isNull);
  });

  test('start position is not a puzzle', () {
    expect(rateFen(Position.startFen), isNull);
  });

  test('a mate in 1 with too many solutions is rejected or listed', () {
    final r = rateFen('k7/8/1K6/8/8/8/8/6Q1 w - - 0 1');
    expect(r == null || r.solutions.length <= maxSolutions, isTrue);
  });

  test('checkmated side has no puzzle', () {
    expect(rateFen('R5k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1'), isNull);
  });

  test('a trade that only wins a defended pawn is not a puzzle', () {
    expect(rateFen('4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1'), isNull);
  });

  test('ladder mate in 2 is found with its mirror twin', () {
    final r = rateFen('7k/8/8/8/8/8/R7/1R4K1 w - - 0 1');
    expect(r, isNotNull);
    expect(r!.mateIn, 2);
    expect(r.solutions, ['a2a7', 'b1b7']);
    expect(r.tier, 4);
  });
}
