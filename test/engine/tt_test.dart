import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/move.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart' show mateScore;
import 'package:chess_solver/engine/tt.dart';
import 'package:flutter_test/flutter_test.dart';

Position _play(String fen, List<String> ucis) {
  var pos = Position.fromFen(fen);
  for (final u in ucis) {
    pos = pos.makeMove(pos.legalMoves().firstWhere((m) => m.uci == u));
  }
  return pos;
}

void main() {
  test('hash: transpositions agree, side to move and rights differ', () {
    final a = _play(Position.startFen, ['g1f3', 'g8f6', 'b1c3', 'b8c6']);
    final b = _play(Position.startFen, ['b1c3', 'b8c6', 'g1f3', 'g8f6']);
    expect(TranspositionTable.hashOf(a), TranspositionTable.hashOf(b));
    final white = Position.fromFen('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
    final black = Position.fromFen('4k3/8/8/8/8/8/8/4K3 b - - 0 1');
    expect(TranspositionTable.hashOf(white), isNot(TranspositionTable.hashOf(black)));
    final rights = Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    final none = Position.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1');
    expect(TranspositionTable.hashOf(rights), isNot(TranspositionTable.hashOf(none)));
  });

  test('hash: en passant square changes the key', () {
    final ep = _play(Position.startFen, ['e2e4']);
    final noEp = Position.fromFen(
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    expect(TranspositionTable.hashOf(ep), isNot(TranspositionTable.hashOf(noEp)));
  });

  test('table: store and find; deeper entry is kept; mate scores shift by ply', () {
    final t = TranspositionTable(10);
    const move = Move(12, 28, flag: Move.doublePush);
    t.store(5, 77, 6, 120, ScoreBound.exact, move, 2);
    final i = t.find(5, 77);
    expect(i, isNonNegative);
    expect(t.depthAt(i), 6);
    expect(t.boundAt(i), ScoreBound.exact);
    expect(t.scoreAt(i, 2), 120);
    expect(TranspositionTable.sameMove(t.moveAt(i), move), isTrue);
    expect(t.find(5, 78), -1, reason: 'other position, same slot');
    t.store(5, 77, 3, 999, ScoreBound.exact, null, 2); // shallower: ignored
    expect(t.scoreAt(t.find(5, 77), 2), 120);
    // A mate seen 3 plies below ply 4 is "mate in 7 from the root" at ply 4
    // and must read back as mate in 3 plies at ply 0.
    t.store(9, 1, 4, mateScore - 7, ScoreBound.exact, null, 4);
    expect(t.scoreAt(t.find(9, 1), 0), mateScore - 3);
  });

  test('search with and without the table agree on a back-rank mate', () {
    final pos = Position.fromFen('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1');
    final off = Searcher(useTable: false).search(pos, maxDepth: 4, millis: 60000)!;
    final on = Searcher().search(pos, maxDepth: 4, millis: 60000)!;
    expect(on.best.$1.uci, 'a1a8');
    expect(off.best.$1.uci, 'a1a8');
    expect(on.best.$2, off.best.$2);
  });

  test('table search prunes: fewer nodes than without, same best move', () {
    final pos = Position.fromFen(
        'r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 7');
    final off = Searcher(useTable: false).search(pos, maxDepth: 4, millis: 60000)!;
    final on = Searcher().search(pos, maxDepth: 4, millis: 60000)!;
    expect(on.nodes, lessThan(off.nodes));
    expect(on.best.$1.uci, off.best.$1.uci);
  });
}
