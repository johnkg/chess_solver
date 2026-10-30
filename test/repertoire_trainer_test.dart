import 'dart:math';

import 'package:chess_solver/engine/repertoire.dart';
import 'package:chess_solver/lessons/lessons.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/line_trainer.dart';
import 'package:chess_solver/ui/line_viewer.dart';
import 'package:chess_solver/ui/practice_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/repertoire_trainer.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A random source whose answer the test chooses.
class _Fixed implements Random {
  int value = 0;
  @override
  int nextInt(int max) => value.clamp(0, max - 1);
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

const lesson = Lesson(
  id: 'test',
  level: 8,
  kind: LessonKind.line,
  title: 'Open Game',
  tagline: '',
  why: '',
  spot: ['', '', ''],
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  side: 'white',
  line: ['e4', 'e5', 'Nf3', 'Nc6'],
  notes: ['Claims the center.', '', 'Develops.', ''],
  branches: ['e4 e5 Nf3 d6'],
  branchNames: ['Philidor Defence'],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: home));
    await tester.pumpAndSettle();
  }

  Offset at(WidgetTester tester, String sq, {bool flipped = false}) {
    final rect = tester.getRect(find.byType(BoardView));
    final cell = rect.width / 8;
    final f = sq.codeUnitAt(0) - 97;
    final r = sq.codeUnitAt(1) - 49;
    return flipped
        ? Offset(rect.right - (f + 0.5) * cell, rect.top + (r + 0.5) * cell)
        : Offset(rect.left + (f + 0.5) * cell, rect.bottom - (r + 0.5) * cell);
  }

  Future<void> play(WidgetTester tester, String uci) async {
    await tester.tapAt(at(tester, uci.substring(0, 2)));
    await tester.pump();
    await tester.tapAt(at(tester, uci.substring(2, 4)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('every variation can be played; the opponent switches to the unfinished one', (tester) async {
    final progress = ProgressStore();
    final rng = _Fixed();
    await show(tester, RepertoireTrainer(lesson: lesson, progress: progress, random: rng));
    expect(find.textContaining('0 of 2 variations learned'), findsOneWidget);

    await play(tester, 'e2e4');
    await play(tester, 'g1f3'); // the opponent answers Nc6: the main line ends
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Game complete with no mistakes'), findsOneWidget);
    expect(find.textContaining('1 more to go'), findsOneWidget);
    expect(find.textContaining('1 of 2 variations learned'), findsOneWidget);
    expect(progress.isSolved(variationProgressId(lesson, 0)), isTrue);
    expect(progress.isSolved(lineProgressId(lesson)), isFalse);

    rng.value = 99; // pick the last branch
    await tester.tap(find.text('Another variation'));
    await tester.pump();
    await play(tester, 'e2e4');
    await play(tester, 'g1f3');
    await tester.pumpAndSettle();
    expect(find.textContaining('Philidor Defence complete'), findsOneWidget);
    expect(find.textContaining('whole repertoire is learned'), findsOneWidget);
    expect(progress.isSolved(variationProgressId(lesson, 1)), isTrue);
    expect(progress.isSolved(lineProgressId(lesson)), isTrue);
  });

  testWidgets('a move outside the repertoire is taken back and counted', (tester) async {
    await show(tester, RepertoireTrainer(lesson: lesson, random: _Fixed()));
    await play(tester, 'd2d4');
    expect(find.textContaining('not in this repertoire'), findsOneWidget);
    expect(find.textContaining('1 mistake'), findsOneWidget);
    await play(tester, 'e2e4'); // still your turn; the book reply follows
    expect(find.textContaining('Your move'), findsOneWidget);
    expect(find.textContaining('e5'), findsWidgets);
    expect(find.textContaining('1 mistake'), findsOneWidget);
  });

  testWidgets('the opponent names the variation it chooses', (tester) async {
    final rng = _Fixed()..value = 99;
    await show(tester, RepertoireTrainer(lesson: lesson, random: rng));
    await play(tester, 'e2e4');
    await play(tester, 'g1f3');
    await tester.pumpAndSettle();
    expect(find.textContaining('Philidor Defence complete'), findsOneWidget);
  });

  testWidgets('hints name a book move', (tester) async {
    await show(tester, RepertoireTrainer(lesson: lesson, random: _Fixed()));
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(find.textContaining('Hint: Claims the center.'), findsOneWidget);
    await tester.tap(find.text('Show move'));
    await tester.pump();
    expect(find.textContaining('A book move is e4'), findsOneWidget);
  });

  testWidgets('finished variations are remembered across visits', (tester) async {
    final progress = ProgressStore();
    await progress.markSolved(variationProgressId(lesson, 0));
    await show(tester, RepertoireTrainer(lesson: lesson, progress: progress, random: _Fixed()));
    expect(find.textContaining('1 of 2 variations learned'), findsOneWidget);
  });

  testWidgets('the real openings all build into trees and the Practice tab opens them', (tester) async {
    final withBranches = lessons.where((l) => l.kind == LessonKind.line && l.branches.isNotEmpty).toList();
    expect(withBranches.length, 8);
    for (final l in withBranches) {
      final rep = Repertoire.fromLines([l.line, for (final b in l.branches) b.split(' ')], [l.title, ...l.branchNames]);
      expect(rep.lineCount, l.branches.length + 1, reason: l.id);
      expect(l.branchNames.length, l.branches.length, reason: l.id);
    }
    await show(tester, PracticeScreen(progress: ProgressStore()));
    await tester.ensureVisible(find.text('Italian Game'));
    expect(find.textContaining('3 variations'), findsWidgets);
    await tester.tap(find.text('Italian Game'));
    await tester.pumpAndSettle();
    expect(find.byType(RepertoireTrainer), findsOneWidget);
    expect(find.textContaining('Two Knights Defence'), findsOneWidget);
  });

  testWidgets('the lesson page lists the variations', (tester) async {
    await show(
      tester,
      Scaffold(body: SingleChildScrollView(child: LineViewer(lesson: lesson, progress: ProgressStore()))),
    );
    expect(find.text('Philidor Defence'), findsOneWidget);
    expect(find.text('Train all 2 variations'), findsOneWidget);
  });
}
