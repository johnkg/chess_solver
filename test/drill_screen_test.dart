import 'dart:math';

import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/lessons/drills.dart';
import 'package:chess_solver/lessons/lessons.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/drill_screen.dart';
import 'package:chess_solver/ui/lesson_screen.dart';
import 'package:chess_solver/ui/practice_screen.dart';
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
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a drill is won by playing it out, and is then saved as solved', (tester) async {
    final drill = drills.firstWhere((d) => d.id == 'dr-square');
    final progress = ProgressStore();
    await show(tester, DrillScreen(drill: drill, progress: progress, random: Random(1)));
    expect(find.textContaining('Your move · 1 of'), findsOneWidget);
    await move(tester, 'c5', 'c6');
    expect(find.textContaining('Your move · 2 of'), findsOneWidget);
    await move(tester, 'c6', 'c7');
    await move(tester, 'c7', 'c8');
    expect(find.textContaining('Promoted'), findsWidgets);
    expect(progress.isSolved('dr-square'), isTrue);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a drill where the engine moves first starts with its move', (tester) async {
    final drill = drills.firstWhere((d) => d.id == 'dr-hold-opp'); // Black to defend, White first
    await show(tester, DrillScreen(drill: drill, random: Random(1)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Your move · 1 of'), findsOneWidget);
  });

  testWidgets('hint gives the idea first', (tester) async {
    final drill = drills.firstWhere((d) => d.id == 'dr-opposition');
    await show(tester, DrillScreen(drill: drill, random: Random(1)));
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(find.textContaining(drill.hint), findsOneWidget);
    expect(find.text('Another hint'), findsOneWidget);
  });

  testWidgets('a plan lesson shows the move, the note and a way to practise', (tester) async {
    final lesson = lessons.firstWhere((l) => l.id == 'eg-opposition');
    await show(tester, LessonScreen(lesson: lesson, progress: ProgressStore()));
    await tester.tap(find.text('Show me'));
    await tester.pump();
    expect(find.textContaining('White plays Ke5'), findsOneWidget);
    expect(find.textContaining(lesson.note!), findsOneWidget);
    expect(find.textContaining('Practise:'), findsOneWidget);
  });

  testWidgets('the Practice tab lists the training positions', (tester) async {
    await show(tester, PracticeScreen(progress: ProgressStore()));
    expect(find.text('TRAINING POSITIONS'), findsOneWidget);
    expect(find.text(drills.first.title), findsOneWidget);
  });
}
