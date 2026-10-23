import 'package:chess_solver/engine/attacks.dart';
import 'package:chess_solver/engine/explainer.dart';
import 'package:chess_solver/engine/insight.dart';
import 'package:chess_solver/engine/move.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_ideas.py, whose logic was verified in Python.
Move moveOf(Position pos, String uci) =>
    pos.legalMoves().firstWhere((m) => m.uci == uci);

Map<Idea, Insight> ideasFor(String fen, String uci) {
  final pos = Position.fromFen(fen);
  return {for (final i in explainMove(pos, moveOf(pos, uci))) i.idea: i};
}

void main() {
  // (name, fen, move, idea that must be found, idea that must be absent)
  final cases = <(String, String, String, Idea?, Idea?)>[
    (
      'knight fork king+rook',
      '3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1',
      'e5f7',
      Idea.fork,
      null,
    ),
    (
      'no fork when the forker can be taken',
      '3kb2r/8/8/4N3/8/8/8/4K3 w - - 0 1',
      'e5f7',
      null,
      Idea.fork,
    ),
    (
      'absolute pin: Bb5 vs Nc6 and Ke8',
      'r1bqkbnr/ppp2ppp/2np4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 4',
      'f1b5',
      Idea.pin,
      null,
    ),
    (
      'no pin when only a pawn is behind',
      'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
      'f1b5',
      null,
      Idea.pin,
    ),
    (
      'relative pin: Re2 vs Ne4 and Qe8',
      '4q1k1/8/8/8/4n3/8/R7/3K4 w - - 0 1',
      'a2e2',
      Idea.pin,
      null,
    ),
    (
      'skewer king then queen',
      '7q/8/8/7k/8/K7/8/R7 w - - 0 1',
      'a1h1',
      Idea.skewer,
      null,
    ),
    (
      'free queen',
      '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1',
      'd1d5',
      Idea.hangingPiece,
      null,
    ),
    (
      'rook for a defended pawn is not a win',
      '4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1',
      'd1d5',
      null,
      Idea.hangingPiece,
    ),
    (
      'queen for a pawn defended by a pawn is not a win',
      '4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1',
      'd1d5',
      null,
      Idea.hangingPiece,
    ),
    (
      'pawn takes a defended queen',
      '4k3/8/2p5/3q4/4P3/8/8/4K3 w - - 0 1',
      'e4d5',
      Idea.hangingPiece,
      null,
    ),
    (
      'back-rank mate',
      '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
      'a1a8',
      Idea.backRankMate,
      Idea.checkmate,
    ),
    (
      "scholar's mate is checkmate, not back rank",
      'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
      'h5f7',
      Idea.checkmate,
      Idea.backRankMate,
    ),
    (
      'smothered mate',
      '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1',
      'g5f7',
      Idea.smotheredMate,
      Idea.checkmate,
    ),
    (
      'double check: Nd6+ uncovers Re1',
      '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1',
      'e4d6',
      Idea.doubleCheck,
      null,
    ),
    (
      'discovered check',
      '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1',
      'e4d6',
      Idea.discoveredAttack,
      null,
    ),
    (
      'discovered check wins the queen',
      '4k3/8/8/3q4/4B3/8/8/4R1K1 w - - 0 1',
      'e4d5',
      Idea.discoveredAttack,
      null,
    ),
    (
      'discovered attack with check hits the queen',
      '4k3/3q4/8/8/4N3/8/8/4R1K1 w - - 0 1',
      'e4f6',
      Idea.discoveredAttack,
      null,
    ),
    (
      'removing the defender: Bxc6 then Nxe5',
      '2bqkb1r/p1pp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQ - 0 1',
      'b5c6',
      Idea.removingDefender,
      Idea.hangingPiece,
    ),
    (
      'a plain check is not a double check',
      '4k3/8/8/8/8/8/8/4R1K1 w - - 0 1',
      'e1e7',
      null,
      Idea.doubleCheck,
    ),
    (
      'a quiet move uncovers nothing',
      '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1',
      'g1h1',
      null,
      Idea.discoveredAttack,
    ),
    (
      'development',
      Position.startFen,
      'g1f3',
      Idea.development,
      null,
    ),
    (
      'center pawn',
      Position.startFen,
      'e2e4',
      Idea.center,
      null,
    ),
    (
      'castling',
      'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
      'e1g1',
      Idea.castling,
      null,
    ),
  ];

  for (final (name, fen, uci, want, notWant) in cases) {
    test(name, () {
      final got = ideasFor(fen, uci);
      if (want != null) expect(got.keys, contains(want), reason: '$got');
      if (notWant != null) {
        expect(got.keys, isNot(contains(notWant)), reason: '$got');
      }
    });
  }

  group('text names real pieces and squares', () {
    test('smothered mate', () {
      final t = ideasFor('6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1', 'g5f7')[
              Idea.smotheredMate]!
          .text;
      for (final w in ['h8', 'f7', 'boxed in']) {
        expect(t, contains(w));
      }
    });

    test('double check', () {
      final t = ideasFor('4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4d6')[
              Idea.doubleCheck]!
          .text;
      for (final w in ['rook', 'e1', 'knight', 'd6', 'e8']) {
        expect(t, contains(w));
      }
    });

    test('fork', () {
      final t = ideasFor('3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7')[Idea.fork]!
          .text;
      for (final w in ['Knight', 'f7', 'd8', 'h8', 'king', 'rook']) {
        expect(t, contains(w));
      }
    });

    test('pin', () {
      final t = ideasFor(
        'r1bqkbnr/ppp2ppp/2np4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 4',
        'f1b5',
      )[Idea.pin]!
          .text;
      expect(t, contains('bishop on b5 pins the knight on c6 to the king on e8'));
    });
  });

  group('static exchange', () {
    test('rook takes a defended pawn loses 400', () {
      final pos = Position.fromFen('4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1');
      expect(seeCapture(pos, moveOf(pos, 'd1d5')), -400);
    });

    test('rook takes a loose pawn wins 100', () {
      final pos = Position.fromFen('4k3/8/8/3p4/8/8/8/3RK3 w - - 0 1');
      expect(seeCapture(pos, moveOf(pos, 'd1d5')), 100);
    });

    test('x-ray recapture is counted', () {
      // exf4 gxf4 Bxf4: White nets one pawn because Bc1 backs up through e3.
      final pos = Position.fromFen(
          '2rqkbnr/ppp2p1p/2n5/3b2p1/1PPP1pP1/PQ2P2P/4K3/RNB3NR w - - 0 1');
      expect(seeCapture(pos, moveOf(pos, 'e3f4')), 100);
    });
  });

  group('verification', () {
    final keep = <(String, String, Idea)>[
      ('3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7', Idea.fork),
      ('7q/8/8/7k/8/K7/8/R7 w - - 0 1', 'a1h1', Idea.skewer),
      ('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d5', Idea.hangingPiece),
      ('4k3/8/2p5/3q4/4P3/8/8/4K3 w - - 0 1', 'e4d5', Idea.hangingPiece),
      ('4k3/3q4/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4f6', Idea.discoveredAttack),
      (
        '2bqkb1r/p1pp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQ - 0 1',
        'b5c6',
        Idea.removingDefender,
      ),
    ];
    test('drops a discovered attack the king can parry', () {
      // Nf6+ uncovers Re1 on Re7, but Kf8 protects the rook: no real win.
      const fen = '6k1/4r3/8/8/4N3/8/8/4R1K1 w - - 0 1';
      final pos = Position.fromFen(fen);
      final m = moveOf(pos, 'e4f6');
      expect(explainMove(pos, m).map((i) => i.idea),
          contains(Idea.discoveredAttack));
      expect(explainVerified(pos, m).map((i) => i.idea),
          isNot(contains(Idea.discoveredAttack)));
    });

    for (final (fen, uci, idea) in keep) {
      test('keeps $idea for $uci', () {
        final pos = Position.fromFen(fen);
        final got = explainVerified(pos, moveOf(pos, uci));
        final hit = got.where((i) => i.idea == idea);
        expect(hit, isNotEmpty, reason: '$got');
        expect(hit.first.verified, isTrue);
      });
    }
  });
}
