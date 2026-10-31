import 'package:chess_solver/engine/clock.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/pgn.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/ui/board_screen.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/new_game_sheet.dart';
import 'package:chess_solver/ui/pgn_dialogs.dart';
import 'package:chess_solver/ui/settings_store.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:chess_solver/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens [open] from a button so dialogs and sheets get a real Navigator.
Widget _host(Future<void> Function(BuildContext) open) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(onPressed: () => open(context), child: const Text('open')),
          ),
        ),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Offset _square(WidgetTester tester, String sq) {
  final rect = tester.getRect(find.byType(BoardView));
  final s = parseSquare(sq);
  final cell = rect.width / 8;
  return Offset(rect.left + (s % 8 + 0.5) * cell, rect.bottom - (s ~/ 8 + 0.5) * cell);
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  await tester.tapAt(_square(tester, from));
  await tester.pump();
  await tester.tapAt(_square(tester, to));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('New game sheet', () {
    testWidgets('shows the starting choice and returns it unchanged', (tester) async {
      NewGameChoice? result;
      _phone(tester);
      await tester.pumpWidget(_host((context) async {
        result = await showNewGameSheet(
          context,
          level: Level.club,
          side: SideChoice.white,
          control: TimeControl.off,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('${Level.club.elo}'), findsWidgets);
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.level, Level.club);
      expect(result!.side, SideChoice.white);
      expect(result!.control, TimeControl.off);
    });

    testWidgets('side and clock changes come back in the choice', (tester) async {
      NewGameChoice? result;
      _phone(tester);
      await tester.pumpWidget(_host((context) async {
        result = await showNewGameSheet(
          context,
          level: Level.club,
          side: SideChoice.white,
          control: TimeControl.off,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Black'));
      await tester.pump();
      await tester.tap(find.text(TimeControl.blitz5.label));
      await tester.pump();
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      expect(result!.side, SideChoice.black);
      expect(result!.control, TimeControl.blitz5);
    });

    testWidgets('slider moves the opponent level and its label', (tester) async {
      NewGameChoice? result;
      _phone(tester);
      await tester.pumpWidget(_host((context) async {
        result = await showNewGameSheet(
          context,
          level: Level.beginner,
          side: SideChoice.white,
          control: TimeControl.off,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(Level.beginner.label), findsOneWidget);
      // Drag the thumb to the far right: the strongest level.
      await tester.drag(find.byType(Slider), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text(Level.grandmaster.label), findsOneWidget);
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      expect(result!.level, Level.grandmaster);
    });

    testWidgets('dismissing returns null', (tester) async {
      var called = false;
      NewGameChoice? result = const NewGameChoice(Level.club, SideChoice.white, TimeControl.off);
      _phone(tester);
      await tester.pumpWidget(_host((context) async {
        result = await showNewGameSheet(
          context,
          level: Level.club,
          side: SideChoice.white,
          control: TimeControl.off,
        );
        called = true;
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 20)); // scrim above the sheet
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
    });
  });

  group('PGN dialogs', () {
    testWidgets('export shows the text and Copy puts it on the clipboard', (tester) async {
      _phone(tester);
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      const pgn = '[Event "t"]\n\n1. e4 e5 *';
      await tester.pumpWidget(_host((context) => showPgnExport(context, pgn)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Export PGN'), findsOneWidget);
      expect(find.textContaining('1. e4 e5'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clip, pgn);
      expect(find.text('Export PGN'), findsNothing);
      expect(find.text('PGN copied.'), findsOneWidget);
    });

    testWidgets('import parses a pasted game', (tester) async {
      _phone(tester);
      PgnGame? game;
      await tester.pumpWidget(_host((context) async {
        game = await showPgnImport(context);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1. e4 e5 2. Nf3 Nc6 *');
      await tester.tap(find.text('Open game'));
      await tester.pumpAndSettle();
      expect(game, isNotNull);
      expect(game!.moves.map((m) => m.uci), ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
    });

    testWidgets('import keeps the dialog open on a bad move and clears the error on edit', (tester) async {
      _phone(tester);
      PgnGame? game;
      await tester.pumpWidget(_host((context) async {
        game = await showPgnImport(context);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1. e4 e4');
      await tester.tap(find.text('Open game'));
      await tester.pumpAndSettle();
      expect(find.text('Import PGN'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.errorText, isNotNull);
      await tester.enterText(find.byType(TextField), '1. e4 e5');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText, isNull);
      expect(game, isNull);
    });

    testWidgets('import with no moves is rejected, cancel returns null', (tester) async {
      _phone(tester);
      PgnGame? game = parsePgn('1. e4 *');
      var called = false;
      await tester.pumpWidget(_host((context) async {
        game = await showPgnImport(context);
        called = true;
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '[Event "x"]');
      await tester.tap(find.text('Open game'));
      await tester.pumpAndSettle();
      expect(find.text('No moves found.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(game, isNull);
    });

    testWidgets('import pastes from the clipboard', (tester) async {
      _phone(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': '1. d4 d5 *'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      PgnGame? game;
      await tester.pumpWidget(_host((context) async {
        game = await showPgnImport(context);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pump();
      await tester.tap(find.text('Open game'));
      await tester.pumpAndSettle();
      expect(game!.moves.map((m) => m.uci), ['d2d4', 'd7d5']);
    });
  });

  group('Board screen', () {
    Future<void> pump(WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const BoardScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('starts with White to move and Undo disabled', (tester) async {
      await pump(tester);
      expect(find.text('White to move'), findsOneWidget);
      final undo = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Undo'));
      expect(undo.onPressed, isNull);
      final rate = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Rate my last move'));
      expect(rate.onPressed, isNull);
    });

    testWidgets('a move flips the turn, Undo and Reset restore the start', (tester) async {
      await pump(tester);
      await _move(tester, 'e2', 'e4');
      expect(find.text('Black to move'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('White to move'), findsOneWidget);
      await _move(tester, 'd2', 'd4');
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('White to move'), findsOneWidget);
      final undo = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Undo'));
      expect(undo.onPressed, isNull);
    });

    testWidgets('Best move shows a coach card; a move clears it', (tester) async {
      await pump(tester);
      expect(find.byType(CoachCard), findsNothing);
      await tester.tap(find.text('Best move'));
      await tester.pump();
      expect(find.byType(CoachCard), findsOneWidget);
      // The analysis described the old board, so a move must hide it.
      await _move(tester, 'e2', 'e4');
      expect(find.byType(CoachCard), findsNothing);
      // Rate my last move works once a move exists.
      await tester.tap(find.text('Rate my last move'));
      await tester.pump();
      expect(find.byType(CoachCard), findsOneWidget);
    });

    testWidgets('Paste FEN loads a position', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Paste FEN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4k3/8/8/8/8/8/8/4K2R b - - 0 1');
      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();
      expect(find.text('Black to move'), findsOneWidget);
    });

    testWidgets('Paste FEN rejects garbage with a snackbar', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Paste FEN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'not a fen');
      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();
      expect(find.text('That is not a valid FEN.'), findsOneWidget);
      expect(find.text('White to move'), findsOneWidget);
    });

    testWidgets('checkmate disables Best move and says who won', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Paste FEN'));
      await tester.pumpAndSettle();
      // Fool's mate: White is checkmated.
      await tester.enterText(
        find.byType(TextField),
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
      );
      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();
      expect(find.text('Black wins by checkmate'), findsOneWidget);
      final best = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Best move'));
      expect(best.onPressed, isNull);
    });
  });
}
