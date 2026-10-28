import 'package:chess_solver/engine/opening_line.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replays a line and numbers the moves', () {
    final line = OpeningLine.fromSan(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    expect(line.length, 5);
    expect(line.positions, hasLength(6));
    expect(line.moves.first.uci, 'e2e4');
    expect(line.numberAt(0), '1.');
    expect(line.numberAt(1), '1...');
    expect(line.numberAt(4), '3.');
    expect(line.positions.last.turn, black);
  });

  test('an illegal move names itself', () {
    expect(
      () => OpeningLine.fromSan(['e4', 'e5', 'Nf6']),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Move 3'))),
    );
  });

  test('check marks and ambiguity letters in the stored SAN are accepted', () {
    final line = OpeningLine.fromSan(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6', 'd4', 'exd4', 'cxd4', 'Bb4+', 'Bd2', 'Bxd2+', 'Nbxd2']);
    expect(line.length, 15);
  });
}
