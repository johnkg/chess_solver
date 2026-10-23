import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/san.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors tool/check_more.py, whose logic was verified in Python.
void main() {
  Set<String> sansOf(String fen) {
    final pos = Position.fromFen(fen);
    return {for (final m in pos.legalMoves()) san(pos, m)};
  }

  test("replays scholar's mate", () {
    var pos = Position.start();
    for (final target in [
      'e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#', //
    ]) {
      final match =
          pos.legalMoves().where((m) => san(pos, m) == target).toList();
      expect(match, hasLength(1), reason: target);
      pos = pos.makeMove(match.single);
    }
    expect(pos.isCheckmate, isTrue);
  });

  test('castling', () {
    expect(sansOf('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
        containsAll(['O-O', 'O-O-O']));
  });

  test('knight disambiguation by file', () {
    expect(sansOf('4k3/8/8/8/8/2N3N1/8/4K3 w - - 0 1'),
        containsAll(['Nce4', 'Nge4']));
  });

  test('rook disambiguation by rank', () {
    expect(sansOf('4k3/R7/8/8/8/8/R7/4K3 w - - 0 1'),
        containsAll(['R7a4', 'R2a4']));
  });

  test('promotion with check', () {
    expect(sansOf('7k/P7/8/8/8/8/8/K7 w - - 0 1'),
        containsAll(['a8=Q+', 'a8=N']));
  });

  test('pawn capture and en passant', () {
    expect(sansOf('4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1'),
        containsAll(['exd5', 'e5']));
    expect(sansOf('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1'),
        containsAll(['exd6', 'e6']));
  });

  test('every move in Kiwipete gets a unique name', () {
    final pos = Position.fromFen(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    final names = [for (final m in pos.legalMoves()) san(pos, m)];
    expect(names, hasLength(48));
    expect(names.toSet(), hasLength(48));
  });
}
