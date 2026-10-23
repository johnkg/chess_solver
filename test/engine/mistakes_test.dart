import 'package:chess_solver/engine/mistakes.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_mistakes.py, whose logic was verified in Python.
void main() {
  Mistake? critique(String fen, String uci) {
    final pos = Position.fromFen(fen);
    return explainMistake(pos, pos.legalMoves().firstWhere((m) => m.uci == uci));
  }

  final cases = <(String, String, String, MistakeKind?, List<String>)>[
    (
      'hangs a rook to the queen',
      '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1',
      'd1d4',
      MistakeKind.losesMaterial,
      ['Qxd4', 'Better was Rxd5'],
    ),
    (
      'misses back-rank mate in 1',
      '3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
      'g1f1',
      MistakeKind.missesMate,
      ['Rxd8#', 'misses a forced mate'],
    ),
    (
      'allows back-rank mate',
      '3r2k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1',
      'b1b2',
      MistakeKind.allowsMate,
      ['Rd1#', 'allows'],
    ),
    (
      'walks into a knight fork',
      '6k1/8/8/8/4n3/8/P7/3R3K w - - 0 1',
      'a2a3',
      MistakeKind.losesMaterial,
      ['Nf2+', 'forks'],
    ),
    (
      'a sound opening move is fine',
      Position.startFen,
      'e2e4',
      null,
      <String>[],
    ),
    (
      'taking the free queen is fine',
      '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1',
      'd1d5',
      null,
      <String>[],
    ),
  ];

  for (final (name, fen, uci, kind, words) in cases) {
    test(name, () {
      final r = critique(fen, uci);
      expect(r?.kind, kind, reason: '${r?.text}');
      for (final w in words) {
        expect(r!.text, contains(w));
      }
    });
  }
}
