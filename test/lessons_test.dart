import 'package:chess_solver/engine/explainer.dart';
import 'package:chess_solver/engine/insight.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/lessons/lessons.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_lessons.py, whose logic was verified in Python.
void main() {
  test('lesson ids are unique and every lesson is filled in', () {
    expect(lessons.map((l) => l.id).toSet(), hasLength(lessons.length));
    for (final l in lessons) {
      expect(l.title, isNotEmpty, reason: l.id);
      expect(l.tagline, isNotEmpty, reason: l.id);
      expect(l.why, isNotEmpty, reason: l.id);
      expect(l.spot, hasLength(3), reason: l.id);
    }
  });

  test('lessons are ordered by level', () {
    final levels = lessons.map((l) => l.level).toList();
    expect(levels, orderedEquals([...levels]..sort()));
  });

  for (final l in lessons) {
    test('${l.id} example is right', () {
      final pos = Position.fromFen(l.fen);
      switch (l.kind) {
        case LessonKind.moves:
          final from = parseSquare(l.square!);
          final got = {
            for (final m in pos.legalMoves())
              if (m.from == from) squareName(m.to),
          };
          expect(got, equals(l.targets.toSet()));
        case LessonKind.status:
          switch (l.status) {
            case 'check':
              expect(pos.inCheck && pos.legalMoves().isNotEmpty, isTrue);
            case 'checkmate':
              expect(pos.isCheckmate, isTrue);
            case 'stalemate':
              expect(pos.isStalemate, isTrue);
            default:
              fail('unknown status ${l.status}');
          }
        case LessonKind.plan:
          final m = pos.legalMoves().firstWhere((m) => m.uci == l.move);
          expect(l.note, isNotEmpty);
          // The pawn endings are checked against a tablebase in
          // tool/check_lessons.py; here the two mates are checked.
          if (l.id == 'eg-kq' || l.id == 'eg-kr') {
            expect(pos.makeMove(m).isCheckmate, isTrue);
          }
        case LessonKind.idea:
          final m = pos.legalMoves().firstWhere((m) => m.uci == l.move);
          final shown = materialIdeas.contains(l.idea)
              ? explainVerified(pos, m)
              : explainMove(pos, m);
          expect(shown.map((i) => i.idea), contains(l.idea),
              reason: shown.toString());
      }
    });
  }
}
