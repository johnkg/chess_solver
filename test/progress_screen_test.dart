import 'package:chess_solver/engine/daily.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:chess_solver/ui/game_viewer.dart';
import 'package:chess_solver/ui/practice_screen.dart';
import 'package:chess_solver/ui/progress_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final now = DateTime(2026, 10, 28, 9);

  Future<void> show(WidgetTester tester, ProgressStore progress) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: ProgressScreen(progress: progress, now: () => now),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a new player sees empty states and no badges', (tester) async {
    await show(tester, ProgressStore());
    expect(find.text('0/${puzzleLibrary.length}'), findsWidgets);
    expect(find.textContaining('Play a rated game to start your rating chart'), findsOneWidget);
    expect(find.textContaining('Finish a game in the Play tab'), findsOneWidget);
    expect(find.text('BADGES · 0 OF 14'), findsOneWidget);
    expect(find.text('Earned'), findsNothing);
  });

  testWidgets('progress shows up: chart, badges, due reviews, themes', (tester) async {
    final progress = ProgressStore();
    for (final p in puzzleLibrary.take(30)) {
      await progress.markSolved(p.id);
    }
    await progress.recordGame(1000, 1);
    await progress.recordGame(1000, 1);
    await progress.recordGame(1400, 0);
    final today = dayNumber(now);
    for (final d in [today - 2, today - 1, today]) {
      await progress.markDaily(d);
    }
    await progress.recordRush(12);
    await progress.recordReview(puzzleLibrary[40].id, correct: false, today: today - 4);
    await progress.recordMiss('fork');
    await show(tester, progress);

    expect(find.text('30/${puzzleLibrary.length}'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // streak and games
    expect(find.textContaining('Play a rated game'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets); // the rating chart
    expect(find.text('Earned'), findsWidgets);
    expect(find.text('First steps'), findsOneWidget);
    expect(find.textContaining('missed 1'), findsOneWidget);
    // Streak of 3 earns "On a roll"; rush 12 earns "Quick eye".
    final earned = tester.widgetList<Semantics>(find.byType(Semantics)).where((s) =>
        s.properties.label?.endsWith('earned') ?? false);
    expect(earned.any((s) => s.properties.label!.startsWith('On a roll')), isTrue);
    expect(earned.any((s) => s.properties.label!.startsWith('Quick eye')), isTrue);
  });

  test('stats count mates, lines and wins', () async {
    final progress = ProgressStore();
    final mates = puzzleLibrary.where((p) => p.mateIn > 0).take(3).toList();
    for (final p in mates) {
      await progress.markSolved(p.id);
    }
    await progress.recordGame(1000, 1);
    final s = statsOf(progress);
    expect(s.puzzlesSolved, 3);
    expect(s.matesSolved, 3);
    expect(s.wins, 1);
    expect(s.gamesPlayed, 1);
    expect(s.linesLearned, 0);
  });

  testWidgets('saved games open in the review viewer', (tester) async {
    final progress = ProgressStore();
    await progress.saveGame(
      '[Event "Casual game"]\n[Date "2026.10.28"]\n[White "You"]\n[Black "Beginner · about 600"]\n[Result "0-1"]\n\n1. f3 e5 2. g4 Qh4# 0-1',
    );
    await show(tester, progress);
    expect(find.text('You vs Beginner · about 600'), findsOneWidget);
    expect(find.textContaining('2026.10.28 · 2 moves · 0-1'), findsOneWidget);
    await tester.ensureVisible(find.text('You vs Beginner · about 600'));
    await tester.tap(find.text('You vs Beginner · about 600'));
    await tester.pumpAndSettle();
    expect(find.byType(GameViewer), findsOneWidget);
  });

  testWidgets('the Practice tab links to the progress screen', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: PracticeScreen(progress: ProgressStore(), now: () => now),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your progress'));
    await tester.pumpAndSettle();
    expect(find.text('Your progress'), findsWidgets);
    expect(find.byType(ProgressScreen), findsOneWidget);
  });
}
