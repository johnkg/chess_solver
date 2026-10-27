import 'package:chess_solver/ui/app.dart';
import 'package:chess_solver/ui/board_controller.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app starts on the Learn tab with three tabs', (tester) async {
    await tester.pumpWidget(const ChessSolverApp());
    expect(find.text('Learn chess'), findsOneWidget);
    expect(find.text('Practice'), findsWidgets);
    expect(find.text('Board'), findsWidgets);
  });

  testWidgets('tabs switch', (tester) async {
    // Phone-sized screen: the default 800x600 test view puts the status line
    // below the board, outside the lazily built ListView.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ChessSolverApp());
    await tester.tap(find.text('Board').last);
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Solved 0 of'), findsOneWidget);
  });

  testWidgets('Play tab: engine answers a move and coach speaks', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ChessSolverApp());
    await tester.tap(find.text('Play').last);
    await tester.pumpAndSettle();
    expect(find.text('Your move'), findsOneWidget);
    final board = find.byType(BoardView);
    final rect = tester.getRect(board);
    Offset at(String sq) {
      final s = parseSquare(sq);
      final cell = rect.width / 8;
      return Offset(rect.left + (s % 8 + 0.5) * cell,
          rect.bottom - (s ~/ 8 + 0.5) * cell);
    }
    await tester.tapAt(at('e2'));
    await tester.pump();
    await tester.tapAt(at('e4'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.textContaining('e4'), findsWidgets);
    expect(find.textContaining('I played'), findsOneWidget);
    expect(find.text('Your move'), findsOneWidget);
    await tester.tap(find.text('Game review'));
    await tester.pump();
    expect(find.textContaining('all of them sound'), findsOneWidget);
  });

  testWidgets('Practice tab shows weak spots', (tester) async {
    SharedPreferences.setMockInitialValues({'missed_ideas': ['fork:2']});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ChessSolverApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('A fork · missed 2'), findsOneWidget);
    expect(find.text('Practice weak spots'), findsOneWidget);
  });

  test('BoardController selects, moves and undoes', () {
    final c = BoardController();
    c.tap(parseSquare('e2'));
    expect(c.targets, {parseSquare('e3'), parseSquare('e4')});
    final m = c.tap(parseSquare('e4'));
    expect(m?.uci, 'e2e4');
    expect(c.position.turn, black);
    c.undo();
    expect(c.position.toFen(), Position.start().toFen());
  });
}
