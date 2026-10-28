import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/structure.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> names(List<int> squares) => {for (final s in squares) squareName(s)};

void main() {
  Position fen(String f) => Position.fromFen(f);

  test('passed pawns, for both sides', () {
    final p = fen('8/8/4k3/3P4/8/8/p7/4K3 w - - 0 1');
    expect(names(conceptSquares(p, Concept.passed, white)), {'d5'});
    expect(names(conceptSquares(p, Concept.passed, black)), {'a2'});
  });

  test('a pawn is not passed when an enemy pawn can stop or capture it', () {
    final p = fen('4k3/3p4/8/4P3/8/8/8/4K3 w - - 0 1'); // d7 attacks e6
    expect(conceptSquares(p, Concept.passed, white), isEmpty);
    final q = fen('4k3/8/8/4P3/8/3p4/8/4K3 w - - 0 1'); // the d3 pawn is already behind e5
    expect(names(conceptSquares(q, Concept.passed, white)), {'e5'});
  });

  test('isolated pawns', () {
    final p = fen('4k3/8/8/8/8/8/P1P1P1P1/4K3 w - - 0 1');
    expect(names(conceptSquares(p, Concept.isolated, white)), {'a2', 'c2', 'e2', 'g2'});
    final q = fen('4k3/8/8/8/8/8/PPP2P1P/4K3 w - - 0 1');
    expect(names(conceptSquares(q, Concept.isolated, white)), {'f2', 'h2'});
  });

  test('doubled pawns are every pawn of a doubled file', () {
    final p = fen('4k3/8/8/8/8/2P5/2P1P3/4K3 w - - 0 1');
    expect(names(conceptSquares(p, Concept.doubled, white)), {'c2', 'c3'});
  });

  test('a backward pawn: behind its neighbours, stop square attacked', () {
    final p = fen('4k3/8/8/4p3/2P1P3/3P4/8/4K3 w - - 0 1');
    expect(names(conceptSquares(p, Concept.backward, white)), {'d3'});
    // An isolated pawn is not backward, and an advance square nobody attacks is fine.
    final q = fen('4k3/8/8/8/2P1P3/3P4/8/4K3 w - - 0 1');
    expect(conceptSquares(q, Concept.backward, white), isEmpty);
    final r = fen('4k3/8/8/4p3/8/3P4/8/4K3 w - - 0 1');
    expect(conceptSquares(r, Concept.backward, white), isEmpty);
  });

  test('open and half-open files', () {
    final p = fen('4k3/ppp2ppp/8/8/8/8/PP3PPP/4K3 w - - 0 1');
    expect(openFiles(p), [3, 4]);
    expect(semiOpenFiles(p, white), [2]);
    expect(semiOpenFiles(p, black), isEmpty);
    expect(conceptFiles(p, Concept.openFile, white), {3, 4});
    expect(conceptSquares(p, Concept.openFile, white), hasLength(16));
  });

  test('an outpost is defended by a pawn and safe from enemy pawns', () {
    final p = fen('4k3/pp3ppp/8/8/4P3/8/PP3PPP/4K3 w - - 0 1');
    expect(names(conceptSquares(p, Concept.outpost, white)), {'d5'}); // f5 can be hit by ...g6
    // Black's mirror image.
    final q = fen('4k3/pp3ppp/8/4p3/8/8/PP3PPP/4K3 w - - 0 1');
    expect(names(conceptSquares(q, Concept.outpost, black)), {'d4'});
  });

  test('an enemy piece on the square, or an own pawn, is not an outpost', () {
    final p = fen('4k3/pp3ppp/8/3n4/4P3/8/PP3PPP/4K3 w - - 0 1');
    expect(conceptSquares(p, Concept.outpost, white), isEmpty);
  });
}
