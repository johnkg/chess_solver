import 'package:chess_solver/engine/pgn.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/game_viewer.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shilling =
    '[White "Beginner"]\n[Black "Blackburne"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3# 0-1';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, {ProgressStore? progress}) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: GameViewer(game: parsePgn(shilling), progress: progress),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('reviewing both sides scores each one', (tester) async {
    await open(tester);
    await tester.tap(find.text('Review both sides'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review of White (Beginner)'), findsOneWidget);
    expect(find.textContaining('Review of Black (Blackburne)'), findsOneWidget);
    expect(find.textContaining('Accuracy 100%'), findsOneWidget); // Black played soundly
    expect(find.textContaining('White played'), findsOneWidget);
    expect(find.textContaining('2 mistakes'), findsOneWidget);
    expect(find.textContaining('Black played 7 moves, all of them sound'), findsOneWidget);
    expect(find.text('Show in the game'), findsNWidgets(2));
  });

  testWidgets('one side can be reviewed alone', (tester) async {
    await open(tester);
    await tester.tap(find.text('Review Black'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review of Black'), findsOneWidget);
    expect(find.textContaining('Review of White'), findsNothing);
  });

  testWidgets('"Show in the game" jumps the board to the mistake', (tester) async {
    await open(tester);
    await tester.tap(find.text('Review White'));
    await tester.pumpAndSettle();
    final first = find.text('Show in the game').first;
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    // The first mistake is 6.Rf1, so the board stands before ply 10 (move 11 of 14).
    expect(find.text('Move 11 of 14'), findsOneWidget);
    expect(find.byType(BoardView), findsWidgets);
  });

  testWidgets('missed ideas can be added to the weak spots, once', (tester) async {
    final progress = ProgressStore();
    await open(tester, progress: progress);
    await tester.tap(find.text('Review White'));
    await tester.pumpAndSettle();
    final button = find.textContaining('Practise these');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(progress.missed, {'hangingPiece': 1}); // allowing mate is not a drillable idea
    expect(find.text('Added to your weak spots'), findsOneWidget);
    expect(find.textContaining('Practise these'), findsNothing);
  });

  testWidgets('no weak-spot button without a progress store', (tester) async {
    await open(tester);
    await tester.tap(find.text('Review White'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Practise these'), findsNothing);
  });
}
