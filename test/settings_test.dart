import 'dart:math';

import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/ui/app.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/piece_painter.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/settings_screen.dart';
import 'package:chess_solver/ui/settings_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsStore', () {
    test('defaults', () {
      final s = SettingsStore();
      expect(s.themeMode, ThemeMode.system);
      expect(s.palette, BoardPalette.slate);
      expect(s.pieces, PieceStyle.solid3d);
      expect(s.defaultLevel, Level.casual);
      expect(s.defaultSide, SideChoice.white);
      expect([s.coach, s.showLegalMoves, s.showCoordinates, s.allowTakeBacks, s.stepHints], everyElement(isTrue));
    });

    test('choices are saved and loaded again', () async {
      final a = SettingsStore();
      await a.setThemeMode(ThemeMode.dark);
      await a.setPalette(BoardPalette.wood);
      await a.setPieces(PieceStyle.flat);
      await a.setDefaultLevel(Level.master);
      await a.setDefaultSide(SideChoice.random);
      await a.setCoach(false);
      await a.setShowLegalMoves(false);
      await a.setShowCoordinates(false);
      await a.setAllowTakeBacks(false);
      await a.setStepHints(false);

      final b = SettingsStore();
      await b.load();
      expect(b.themeMode, ThemeMode.dark);
      expect(b.palette, BoardPalette.wood);
      expect(b.pieces, PieceStyle.flat);
      expect(b.defaultLevel, Level.master);
      expect(b.defaultSide, SideChoice.random);
      expect([b.coach, b.showLegalMoves, b.showCoordinates, b.allowTakeBacks, b.stepHints], everyElement(isFalse));
    });

    test('unknown stored values fall back to the defaults', () async {
      SharedPreferences.setMockInitialValues({'settings_theme': 'purple', 'settings_level': 'nobody'});
      final s = SettingsStore();
      await s.load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.defaultLevel, Level.casual);
    });

    test('a side choice resolves to a colour; random gives both', () {
      final rng = Random(3);
      expect(SideChoice.white.resolve(rng), white);
      expect(SideChoice.black.resolve(rng), black);
      final seen = {for (var i = 0; i < 40; i++) SideChoice.random.resolve(rng)};
      expect(seen, {white, black});
    });
  });

  group('in the app', () {
    Future<void> openApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ChessSolverApp());
      await tester.pumpAndSettle();
    }

    testWidgets('the gear opens Settings and the theme changes at once', (tester) async {
      await openApp(tester);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.light);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness, Brightness.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness, Brightness.light);
    });

    testWidgets('flat pieces and the board colors are used by every board', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Board').last);
      await tester.pumpAndSettle();
      bool anyFlat() => tester
          .widgetList<CustomPaint>(find.descendant(of: find.byType(BoardView), matching: find.byType(CustomPaint)))
          .any((c) => c.painter is PiecePainter && (c.painter! as PiecePainter).flat);
      expect(anyFlat(), isFalse);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flat'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(anyFlat(), isTrue);
    });

    testWidgets('coordinates can be hidden', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Board').last);
      await tester.pumpAndSettle();
      expect(find.text('e'), findsWidgets);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show coordinates'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('e'), findsNothing);
    });

    testWidgets('reset progress needs a second tap', (tester) async {
      SharedPreferences.setMockInitialValues({'solved_puzzles_v4': ['checkmate-1']});
      final progress = ProgressStore();
      await progress.load();
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: SettingsScreen(progress: progress),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reset progress'));
      await tester.tap(find.text('Reset progress'));
      await tester.pump();
      expect(progress.solved, isNotEmpty);
      expect(find.text('Tap again to confirm'), findsOneWidget);
      await tester.tap(find.text('Tap again to confirm'));
      await tester.pumpAndSettle();
      expect(progress.solved, isEmpty);
      expect(find.text('Progress cleared.'), findsOneWidget);
    });

    testWidgets('Play starts from the saved defaults and the sheet changes them for one game', (tester) async {
      SharedPreferences.setMockInitialValues({'settings_level': 'master', 'settings_side': 'black'});
      await openApp(tester);
      await tester.tap(find.text('Play').last);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Master'), findsWidgets);
      expect(find.textContaining('you are Black'), findsOneWidget);
      // The engine (White) has made its first move.
      expect(find.text('Your move'), findsOneWidget);

      await tester.tap(find.byTooltip('New game'));
      await tester.pumpAndSettle();
      expect(find.text('2200'), findsWidgets);
      await tester.tap(find.text('White').last);
      await tester.pump();
      // Drag the slider to the far left: Beginner.
      await tester.drag(find.byType(Slider), const Offset(-800, 0));
      await tester.pump();
      expect(find.text('600'), findsWidgets);
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Beginner'), findsWidgets);
      expect(find.textContaining('you are White'), findsOneWidget);
    });

    testWidgets('coach off hides the coach text; take-backs off disables the button', (tester) async {
      SharedPreferences.setMockInitialValues({'settings_coach': false, 'settings_takebacks': false});
      await openApp(tester);
      await tester.tap(find.text('Play').last);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(BoardView));
      Offset at(String sq) {
        final s = parseSquare(sq);
        final cell = rect.width / 8;
        return Offset(rect.left + (s % 8 + 0.5) * cell, rect.bottom - (s ~/ 8 + 0.5) * cell);
      }
      await tester.tapAt(at('e2'));
      await tester.pump();
      await tester.tapAt(at('e4'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('I played'), findsNothing);
      expect(find.textContaining('is a fine move'), findsNothing);
      final undo = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Take back'));
      expect(undo.onPressed, isNull);
    });
  });
}
