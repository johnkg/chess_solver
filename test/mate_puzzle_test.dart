import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/puzzle_screen.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a mate in 2 plays on until checkmate', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final puzzle = puzzleLibrary.firstWhere((p) => p.mateIn == 2);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: PuzzleScreen(puzzle: puzzle, progress: ProgressStore()),
    ));

    Future<void> play(String uci) async {
      final rect = tester.getRect(find.byType(BoardView));
      final flipped = Position.fromFen(puzzle.fen).turn == 1;
      Offset at(String sq) {
        final s = parseSquare(sq);
        final cell = rect.width / 8;
        final file = flipped ? 7 - s % 8 : s % 8;
        final row = flipped ? s ~/ 8 : 7 - s ~/ 8;
        return Offset(rect.left + (file + 0.5) * cell, rect.top + (row + 0.5) * cell);
      }
      await tester.tapAt(at(uci.substring(0, 2)));
      await tester.pump();
      await tester.tapAt(at(uci.substring(2, 4)));
      await tester.pump();
    }

    await play(puzzle.solutions.first);
    expect(find.textContaining('The opponent defends'), findsOneWidget);
    expect(find.textContaining('Checkmate!'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('Keep going: mate in 1'), findsOneWidget);

    // Finish the mate from whatever the opponent played.
    final position = tester.widget<BoardView>(find.byType(BoardView)).position;
    await play(mateIn(position, 1)!.uci);
    expect(find.textContaining('Checkmate!'), findsOneWidget);
  });
}
