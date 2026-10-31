import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/move.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

Move _uci(Position pos, String uci) => pos.legalMoves().firstWhere((m) => m.uci == uci);

/// Plays [ucis] from [start]; returns the final position and the keys of every
/// position before it.
(Position, List<String>) _play(Position start, List<String> ucis) {
  var pos = start;
  final seen = <String>[];
  for (final u in ucis) {
    seen.add(pos.repetitionKey);
    pos = pos.makeMove(_uci(pos, u));
  }
  return (pos, seen);
}

void main() {
  const shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];

  test('repetitionKey ignores the move counters but not the side to move', () {
    final a = Position.fromFen('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
    final b = Position.fromFen('4k3/8/8/8/8/8/8/4K3 w - - 12 40');
    final c = Position.fromFen('4k3/8/8/8/8/8/8/4K3 b - - 0 1');
    expect(a.repetitionKey, b.repetitionKey);
    expect(a.repetitionKey, isNot(c.repetitionKey));
  });

  test('drawReason: third occurrence is a draw, second is not', () {
    final (second, seen2) = _play(Position.start(), shuffle);
    expect(second.repetitionKey, Position.start().repetitionKey);
    expect(drawReason(second, seen: seen2), isNull);
    final (third, seen3) = _play(Position.start(), [...shuffle, ...shuffle]);
    expect(drawReason(third, seen: seen3), 'Draw by threefold repetition');
  });

  test('a capture or pawn move resets repetition', () {
    final (pos, seen) = _play(Position.start(), [...shuffle, 'e2e4', 'e7e5', ...shuffle]);
    expect(drawReason(pos, seen: seen), isNull);
  });

  test('search scores a move that repeats an earlier position as a draw', () {
    final start = Position.fromFen('4k3/8/8/8/8/8/8/Q3K3 w - - 10 20');
    final after = start.makeMove(_uci(start, 'a1a2'));
    final plain = Searcher().search(start, maxDepth: 2, millis: 5000, margin: 5000)!;
    final withHistory = Searcher().search(
      start,
      maxDepth: 2,
      millis: 5000,
      margin: 5000,
      history: [after.repetitionKey],
    )!;
    int score(SearchResult r) => r.moves.firstWhere((e) => e.$1.uci == 'a1a2').$2;
    expect(score(plain), greaterThan(300), reason: 'a queen up');
    expect(score(withHistory), 0);
    expect(withHistory.best.$1.uci, isNot('a1a2'));
  });
}
