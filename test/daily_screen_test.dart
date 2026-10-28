import 'package:chess_solver/engine/daily.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/ui/practice_screen.dart';
import 'package:chess_solver/ui/puzzle_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime(2026, 10, 28, 9);

  Future<ProgressStore> open(WidgetTester tester, {Set<int> done = const {}}) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final progress = ProgressStore();
    for (final d in done) {
      await progress.markDaily(d);
    }
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: PracticeScreen(progress: progress, now: () => now),
    ));
    await tester.pumpAndSettle();
    return progress;
  }

  testWidgets('shows today\'s puzzle with no streak yet', (tester) async {
    await open(tester);
    expect(find.textContaining('DAILY PUZZLE · OCT 28'), findsOneWidget);
    expect(find.text('Solve today\'s puzzle'), findsOneWidget);
    expect(find.textContaining('start a streak'), findsOneWidget);
  });

  testWidgets('shows the streak and that today is done', (tester) async {
    final today = dayNumber(now);
    await open(tester, done: {today - 2, today - 1, today});
    expect(find.text('Solved today'), findsOneWidget);
    expect(find.textContaining('3-day streak'), findsOneWidget);
    expect(find.text('Play it again'), findsOneWidget);
  });

  testWidgets('the button opens the day\'s puzzle', (tester) async {
    await open(tester);
    await tester.tap(find.text('Solve today\'s puzzle'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardView), findsOneWidget);
    expect(dailyPuzzle(puzzleLibrary, dayNumber(now)).fen, isNotEmpty);
  });

  testWidgets('solving the daily puzzle marks the day', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final progress = ProgressStore();
    final puzzle = puzzleLibrary.firstWhere((p) => p.mateIn == 1);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: PuzzleScreen(puzzle: puzzle, progress: progress, dailyDay: 20000),
    ));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(BoardView));
    final flipped = Position.fromFen(puzzle.fen).turn == black;
    Offset at(String sq) {
      final s = parseSquare(sq);
      final cell = rect.width / 8;
      final f = s % 8, r = s ~/ 8;
      return flipped
          ? Offset(rect.right - (f + 0.5) * cell, rect.top + (r + 0.5) * cell)
          : Offset(rect.left + (f + 0.5) * cell, rect.bottom - (r + 0.5) * cell);
    }
    final uci = puzzle.solutions.first;
    await tester.tapAt(at(uci.substring(0, 2)));
    await tester.pump();
    await tester.tapAt(at(uci.substring(2, 4)));
    await tester.pumpAndSettle();
    expect(progress.dailyDays, {20000});
  });
}
