import 'package:chess_solver/engine/mistakes.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/review.dart';
import 'package:chess_solver/ui/board_view.dart';
import 'package:chess_solver/ui/review_snapshot.dart';
import 'package:chess_solver/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewEntry _blunder() {
  final pos = Position.fromFen('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1');
  final move = pos.legalMoves().firstWhere((m) => m.uci == 'd1d4');
  return reviewMove(pos, move, ply: 0, mistake: explainMistake(pos, move));
}

void main() {
  test('a review entry keeps the position before the move', () {
    final e = _blunder();
    expect(e.isMistake, isTrue);
    expect(e.fen, '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1');
  });

  testWidgets('snapshot shows the board at the time, then what happened', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entry = _blunder();
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: ReviewSnapshot(entry: entry))),
    ));
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.textContaining('You played ${entry.san} (red)'), findsOneWidget);
    var board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.position.toFen(), entry.fen);
    expect(board.arrows.length, 2);

    await tester.tap(find.text('What happened'));
    await tester.pump();
    expect(find.textContaining('is the reply'), findsOneWidget);
    board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.position.toFen(), isNot(entry.fen));
    expect(board.arrows.length, 1);
  });
}
