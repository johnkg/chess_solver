import 'package:chess_solver/engine/move.dart';
import 'package:chess_solver/engine/pgn.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/san.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fools = '''
[Event "Test"]
[White "A"]
[Black "B"]
[Result "0-1"]

1. f3 e5 2. g4 Qh4# 0-1
''';

  test('reads tags, moves and result', () {
    final g = parsePgn(fools);
    expect(g.white, 'A');
    expect(g.black, 'B');
    expect(g.moves.length, 4);
    expect(g.result, '0-1');
    expect(g.positions.last.isCheckmate, isTrue);
  });

  test('skips comments, variations, NAGs, move numbers and check marks', () {
    final g = parsePgn(
      '1. e4 {best by test} e5 \$1 (1... c5 2. Nf3) 2. Nf3 ; rest of line\nNc6 3. Bb5 a6 *',
    );
    expect(g.moves.length, 6);
    expect(g.result, '*');
    final p = g.positions.last;
    expect(san(g.positions[g.moves.length - 1], g.moves.last), 'a6');
    expect(p.turn, 0);
  });

  test('castling written with zeros and promotion without "="', () {
    final g = parsePgn('1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. 0-0 Nf6');
    expect(g.moves.length, 8);
    final promo = parsePgn(
      '[FEN "8/P6k/8/8/8/8/8/K7 w - - 0 1"]\n\n1. a8Q+ Kg7',
    );
    expect(promo.moves.length, 2);
  });

  test('an illegal move names itself', () {
    expect(
      () => parsePgn('1. e4 e5 2. Ke3'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Move 3'))),
    );
    expect(() => parsePgn('[Event "x"]'), throwsFormatException);
  });

  test('export then import gives back the same game', () {
    final moves = parsePgn(fools).moves;
    final text = toPgn(moves, headers: {'White': 'A', 'Black': 'B'});
    expect(text, contains('[Result "0-1"]'));
    expect(text, contains('1. f3 e5 2. g4 Qh4# 0-1'));
    final back = parsePgn(text);
    expect(back.moves, moves);
    expect(back.white, 'A');
  });

  test('a game from another start keeps its FEN and numbering', () {
    final start = Position.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    final g = parsePgn('[FEN "${start.toFen()}"]\n\n1... e5 2. Nf3');
    final text = toPgn(g.moves, start: start, result: '*');
    expect(text, contains('[FEN "${start.toFen()}"]'));
    expect(text, contains('1... e5 2. Nf3 *'));
    expect(parsePgn(text).moves, g.moves);
  });

  test('result follows the final position', () {
    final g = parsePgn(fools);
    expect(pgnResult(g.positions.last), '0-1');
    expect(pgnResult(Position.start()), '*');
  });

  test('long games wrap lines at 80 columns', () {
    final line = ['Nf3', 'Nf6', 'Ng1', 'Ng8'];
    final pos = Position.start();
    var p = pos;
    final moves = <Move>[];
    for (var i = 0; i < 24; i++) {
      final m = moveFromSan(p, line[i % 4])!;
      moves.add(m);
      p = p.makeMove(m);
    }
    final text = toPgn(moves);
    final body = text.split('\n\n').last.trimRight().split('\n');
    expect(body.length, greaterThan(1));
    expect(body.every((l) => l.length <= 80), isTrue);
    expect(parsePgn(text).moves, moves);
  });

  test('pgnResultForScore maps a score and colour to the tag', () {
    expect(pgnResultForScore(null, white), '*');
    expect(pgnResultForScore(0.5, black), '1/2-1/2');
    expect(pgnResultForScore(1, white), '1-0');
    expect(pgnResultForScore(1, black), '0-1');
    expect(pgnResultForScore(0, white), '0-1');
    expect(pgnResultForScore(0, black), '1-0');
  });

  test('pgnDate pads month and day', () {
    expect(pgnDate(DateTime(2026, 3, 7)), '2026.03.07');
  });
}
