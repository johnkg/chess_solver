import 'package:chess_solver/engine/daily.dart';
import 'package:chess_solver/engine/puzzle.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/practice_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/puzzle_screen.dart';
import 'package:chess_solver/ui/rush_screen.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const backRank = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';

Puzzle rushPuzzle(String id, {int tier = 1}) => Puzzle(
      id: id,
      fen: backRank,
      solutions: const ['d1d8'],
      san: 'Rd8#',
      idea: null,
      mateIn: 1,
      tier: tier,
      text: 'Back-rank mate.',
      source: 'hand',
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

  Offset at(WidgetTester tester, String sq) {
    final rect = tester.getRect(find.byType(BoardView));
    final cell = rect.width / 8;
    return Offset(
      rect.left + (sq.codeUnitAt(0) - 97 + 0.5) * cell,
      rect.bottom - (sq.codeUnitAt(1) - 49 + 0.5) * cell,
    );
  }

  Future<void> move(WidgetTester tester, String uci) async {
    await tester.tapAt(at(tester, uci.substring(0, 2)));
    await tester.pump();
    await tester.tapAt(at(tester, uci.substring(2, 4)));
    await tester.pump();
  }

  group('Puzzle Rush', () {
    testWidgets('solving counts, three wrong moves end the run and the best is kept', (tester) async {
      final progress = ProgressStore();
      await show(tester, RushScreen(progress: progress, puzzles: [for (var i = 0; i < 5; i++) rushPuzzle('p$i')]));
      expect(find.text('Start'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('3:00'), findsOneWidget);
      await move(tester, 'd1d8');
      expect(find.text('Solved 1'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await move(tester, 'd1d2');
      }
      await tester.pumpAndSettle();
      expect(find.text('Out of strikes'), findsOneWidget);
      expect(find.textContaining('You solved 1.'), findsOneWidget);
      expect(progress.rushBest, 1);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('the clock ends the run', (tester) async {
      final progress = ProgressStore();
      await show(tester, RushScreen(progress: progress, puzzles: [rushPuzzle('a'), rushPuzzle('b')], seconds: 2));
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:01'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Time is up'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('skipping costs a strike', (tester) async {
      await show(tester, RushScreen(progress: ProgressStore(), puzzles: [rushPuzzle('a'), rushPuzzle('b')]));
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.tap(find.text('Skip (a strike)'));
      await tester.pump();
      expect(find.textContaining('Strike 1 of 3'), findsOneWidget);
    });
  });

  group('puzzle screen', () {
    testWidgets('a miss starts spaced review, a later clean solve moves it up', (tester) async {
      final progress = ProgressStore();
      final puzzle = rushPuzzle('review-me');
      await show(tester, PuzzleScreen(puzzle: puzzle, progress: progress, today: 100));
      await move(tester, 'd1d2'); // wrong
      expect(progress.srsCards['review-me']!.due, 101);
      await move(tester, 'd1d8'); // right, but after a miss: no promotion
      await tester.pumpAndSettle();
      expect(progress.srsCards['review-me']!.box, 0);

      await show(tester, PuzzleScreen(key: UniqueKey(), puzzle: puzzle, progress: progress, today: 101));
      await move(tester, 'd1d8');
      await tester.pumpAndSettle();
      expect(progress.srsCards['review-me']!.box, 1);
      expect(progress.srsCards['review-me']!.due, 104);
    });

    testWidgets('a next button follows the supplied run', (tester) async {
      final a = rushPuzzle('a');
      final b = rushPuzzle('b');
      await show(
        tester,
        PuzzleScreen(
          puzzle: a,
          progress: ProgressStore(),
          nextLabel: 'Next review',
          nextPuzzle: (seen) => seen.contains('b') ? null : b,
        ),
      );
      expect(find.text('Next review'), findsNothing);
      await move(tester, 'd1d8');
      await tester.pumpAndSettle();
      expect(find.text('Next review'), findsOneWidget);
      await tester.tap(find.text('Next review'));
      await tester.pumpAndSettle();
      expect(find.text('Next review'), findsNothing); // new puzzle, unsolved
      await move(tester, 'd1d8');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next review'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleScreen), findsNothing); // run over: back out
    });
  });

  group('practice tab', () {
    final now = DateTime(2026, 10, 28, 9);

    testWidgets('shows reviews that are due', (tester) async {
      final progress = ProgressStore();
      await progress.recordReview(puzzleLibrary.first.id, correct: false, today: dayNumber(now) - 3);
      await show(tester, PracticeScreen(progress: progress, now: () => now));
      expect(find.text('SPACED REVIEW'), findsOneWidget);
      expect(find.text('1 puzzle to review'), findsOneWidget);
      await tester.tap(find.text('Start review'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleScreen), findsOneWidget);
    });

    testWidgets('no review card when nothing is due', (tester) async {
      await show(tester, PracticeScreen(progress: ProgressStore(), now: () => now));
      expect(find.text('SPACED REVIEW'), findsNothing);
    });

    testWidgets('a theme chip limits the list and the path', (tester) async {
      await show(tester, PracticeScreen(progress: ProgressStore(), now: () => now));
      expect(find.text('Win material'), findsWidgets);
      final chip = find.textContaining('Forced mates ·');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Win material'), findsNothing);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next for you'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleScreen), findsOneWidget);
      expect(find.text('Mate in 2'), findsOneWidget); // the easiest forced mate
    });

    testWidgets('Puzzle Rush opens from the tab', (tester) async {
      await show(tester, PracticeScreen(progress: ProgressStore(), now: () => now));
      await tester.ensureVisible(find.text('Puzzle Rush'));
      await tester.tap(find.text('Puzzle Rush'));
      await tester.pumpAndSettle();
      expect(find.text('Three minutes, three strikes'), findsOneWidget);
    });
  });
}
