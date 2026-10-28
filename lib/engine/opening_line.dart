import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'san.dart';

/// An opening line replayed from SAN: the moves and the position before each
/// of them (plus the final one).
class OpeningLine {
  OpeningLine._(this.sans, this.moves, this.positions);

  /// Replays [sans] from the start position. Throws [FormatException] naming
  /// the first move that is not legal.
  factory OpeningLine.fromSan(List<String> sans, {Position? start}) {
    final positions = <Position>[start ?? Position.start()];
    final moves = <Move>[];
    for (var i = 0; i < sans.length; i++) {
      final m = moveFromSan(positions.last, sans[i]);
      if (m == null) {
        throw FormatException('Move ${i + 1} (${sans[i]}) is not legal.');
      }
      moves.add(m);
      positions.add(positions.last.makeMove(m));
    }
    return OpeningLine._(sans, moves, positions);
  }

  final List<String> sans;
  final List<Move> moves;

  /// `positions[i]` is the board before `moves[i]`; the last one is the end.
  final List<Position> positions;

  int get length => moves.length;

  /// "1." for White's moves, "1..." for Black's, as written before ply [i].
  String numberAt(int i) {
    final p = positions[i];
    return p.turn == white ? '${p.fullmove}.' : '${p.fullmove}...';
  }
}
