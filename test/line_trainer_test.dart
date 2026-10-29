import 'package:chess_solver/engine/opening_line.dart';
import 'package:chess_solver/lessons/lessons.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/learn_screen.dart';
import 'package:chess_solver/ui/line_trainer.dart';
import 'package:chess_solver/ui/lesson_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Taps [uci]; with [settle] it waits for the book reply as well.
  Future<void> play(WidgetTester tester, String uci,
      {bool flipped = false, bool settle = true}) async {
    await tester.tapAt(at(tester, uci.substring(0, 2), flipped: flipped));
    await tester.pump();
    await tester.tapAt(at(tester, uci.substring(2, 4), flipped: flipped));
    await tester.pump(const Duration(milliseconds: 50));
    if (settle) {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    }
  }

  testWidgets('playing the whole line from memory finishes it and saves it', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'op-london');
    final progress = ProgressStore();
    await show(tester, LineTrainer(lesson: lesson, progress: progress));
    final line = OpeningLine.fromSan(lesson.line);
    for (var i = 0; i < line.length; i += 2) {
      await play(tester, line.moves[i].uci);
    }
    await tester.pumpAndSettle();
    expect(find.text('Line complete with no mistakes!'), findsOneWidget);
    expect(progress.isSolved(lineProgressId(lesson)), isTrue);
  });

  testWidgets('a whole famous game can be replayed from the winner\'s side', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'gm-lasker-thomas');
    final progress = ProgressStore();
    await show(tester, LineTrainer(lesson: lesson, progress: progress));
    final line = OpeningLine.fromSan(lesson.line);
    for (var i = 0; i < line.length; i += 2) {
      await play(tester, line.moves[i].uci);
    }
    await tester.pumpAndSettle();
    expect(find.text('Line complete with no mistakes!'), findsOneWidget);
    expect(progress.isSolved(lineProgressId(lesson)), isTrue);
  });

  testWidgets('a wrong move is taken back and counted', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'op-italian');
    await show(tester, LineTrainer(lesson: lesson));
    await play(tester, 'a2a3');
    expect(find.textContaining('Not the book move'), findsOneWidget);
    expect(find.textContaining('1 mistake'), findsOneWidget);
    // The board is back at the start: the right move still works.
    await play(tester, 'e2e4', settle: false);
    expect(find.textContaining('Correct: e4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('studying Black: the book move for White is played first', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'op-najdorf');
    await show(tester, LineTrainer(lesson: lesson));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your move: 1...'), findsOneWidget);
    await play(tester, 'c7c5', flipped: true, settle: false);
    expect(find.textContaining('Correct: c5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('hint gives the idea, then the move', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'op-ruy');
    await show(tester, LineTrainer(lesson: lesson));
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(find.textContaining('Hint:'), findsOneWidget);
    await tester.tap(find.text('Show move'));
    await tester.pump();
    expect(find.textContaining('The book move is e4'), findsOneWidget);
  });

  testWidgets('the lesson page steps through the line with notes', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'op-italian');
    await show(tester, LessonScreen(lesson: lesson, progress: ProgressStore()));
    await tester.tap(find.byTooltip('Next move'));
    await tester.pump();
    expect(find.text('1. e4'), findsWidgets);
    expect(find.textContaining('Claims the center'), findsOneWidget);
    expect(find.text('Train this line'), findsOneWidget);
  });

  testWidgets('Learn tab filters by phase', (tester) async {
    await show(tester, LearnScreen(progress: ProgressStore()));
    expect(find.text('The pawn'), findsWidgets);
    await tester.tap(find.text('Openings'));
    await tester.pumpAndSettle();
    expect(find.text('Italian Game'), findsOneWidget);
    expect(find.text('The pawn'), findsNothing);
    await tester.ensureVisible(find.text('Endgames'));
    await tester.tap(find.text('Endgames'));
    await tester.pumpAndSettle();
    expect(find.text('The opposition'), findsOneWidget);
    expect(find.text('Italian Game'), findsNothing);
  });
}
