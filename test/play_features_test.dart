import 'dart:math';

import 'package:chess_solver/engine/clock.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/play_screen.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProgressStore> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final progress = ProgressStore();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: PlayScreen(progress: progress, random: Random(1)),
    ));
    await tester.pumpAndSettle();
    return progress;
  }

  Future<void> move(WidgetTester tester, String from, String to) async {
    final rect = tester.getRect(find.byType(BoardView));
    Offset at(String sq) {
      final s = parseSquare(sq);
      final cell = rect.width / 8;
      return Offset(rect.left + (s % 8 + 0.5) * cell, rect.bottom - (s ~/ 8 + 0.5) * cell);
    }
    await tester.tapAt(at(from));
    await tester.pump();
    await tester.tapAt(at(to));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('hint: first the piece, then the move', (tester) async {
    await open(tester);
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(find.textContaining('look at your'), findsOneWidget);
    expect(find.text('Show move'), findsOneWidget);
    await tester.tap(find.text('Show move'));
    await tester.pump();
    expect(find.textContaining('Best move'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
  });

  testWidgets('take back works with a clock and hands the turn back', (tester) async {
    await open(tester);
    await tester.tap(find.byType(DropdownMenu<TimeControl>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 min').last);
    await tester.pumpAndSettle();
    await move(tester, 'e2', 'e4');
    expect(find.textContaining('I played'), findsOneWidget);
    await tester.tap(find.text('Take back'));
    await tester.pump();
    expect(find.textContaining('I played'), findsNothing);
    expect(find.text('Your move'), findsOneWidget);
    // Hand-made clock label for the side to move is running again.
    expect(find.textContaining('4:'), findsWidgets);
    // Stop the 100 ms ticker started for the clock.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a game with a take-back is practice, not rated', (tester) async {
    final progress = await open(tester);
    await move(tester, 'f2', 'f3');
    await tester.tap(find.text('Take back'));
    await tester.pump();
    await move(tester, 'e2', 'e4');
    await tester.tap(find.text('Resign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign').last);
    await tester.pumpAndSettle();
    expect(find.text('You resigned'), findsOneWidget);
    expect(find.textContaining('Practice game'), findsOneWidget);
    expect(progress.games, isEmpty);
  });

  testWidgets('resigning a clean game costs rating', (tester) async {
    final progress = await open(tester);
    await move(tester, 'e2', 'e4');
    await move(tester, 'd2', 'd4');
    await tester.tap(find.text('Resign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign').last);
    await tester.pumpAndSettle();
    expect(progress.games.length, 1);
    expect(progress.rating, lessThan(1000));
    expect(find.textContaining('Rating'), findsWidgets);
  });
}
