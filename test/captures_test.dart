import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/ui/board_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void play(BoardController c, String from, String to) {
  c.tap(parseSquare(from));
  c.tap(parseSquare(to));
}

void main() {
  test('captures are listed per side, most valuable first', () {
    final c = BoardController();
    play(c, 'e2', 'e4');
    play(c, 'd7', 'd5');
    play(c, 'e4', 'd5'); // white takes a pawn
    play(c, 'd8', 'd5'); // black takes a pawn
    play(c, 'b1', 'c3');
    play(c, 'd5', 'e5'); // quiet
    expect(c.capturedBy(white), [pawn]);
    expect(c.capturedBy(black), [pawn]);
    play(c, 'c3', 'e4'); // knight to e4
    play(c, 'e5', 'e4'); // black queen takes the knight
    expect(c.capturedBy(black), [knight, pawn]);
    expect(c.capturedBy(white), [pawn]);
  });

  test('en passant counts as a pawn capture and undo takes it back', () {
    final c = BoardController(Position.fromFen('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1'));
    play(c, 'e5', 'd6');
    expect(c.capturedBy(white), [pawn]);
    c.undo();
    expect(c.capturedBy(white), isEmpty);
  });
}
