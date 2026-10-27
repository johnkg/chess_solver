import 'dart:math';

import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'san.dart';

/// A small opening repertoire, written as SAN lines. The lines are replayed
/// into a table of board -> moves, so transpositions work and the computer
/// picks a random book move each game instead of one fixed line.
const List<String> _lines = [
  // Open games
  'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5 Bb3 d6 c3 O-O h3 Nb8',
  'e4 e5 Nf3 Nc6 Bb5 Nf6 O-O Nxe4 d4 Nd6 Bxc6 dxc6 dxe5 Nf5 Qxd8+ Kxd8',
  'e4 e5 Nf3 Nc6 Bc4 Bc5 c3 Nf6 d3 d6 O-O O-O Re1 a6',
  'e4 e5 Nf3 Nc6 Bc4 Nf6 d3 Bc5 c3 d6 O-O O-O Re1 a6',
  'e4 e5 Nf3 Nc6 d4 exd4 Nxd4 Nf6 Nxc6 bxc6 e5 Qe7 Qe2 Nd5 c4 Ba6',
  'e4 e5 Nf3 Nf6 Nxe5 d6 Nf3 Nxe4 d4 d5 Bd3 Nc6 O-O Be7 c4 Nb4',
  'e4 e5 Nc3 Nf6 f4 d5 fxe5 Nxe4 Nf3 Be7 d4 O-O',
  // Sicilian
  'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be3 e5 Nb3 Be6 f3 Be7',
  'e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 Nf6 Nc3 d6 Bg5 e6 Qd2 a6 O-O-O Bd7',
  'e4 c5 Nf3 e6 d4 cxd4 Nxd4 Nc6 Nc3 Qc7 Be3 a6 Be2 Nf6 O-O Bb4',
  'e4 c5 c3 Nf6 e5 Nd5 d4 cxd4 Nf3 Nc6 cxd4 d6 Bc4 Nb6 Bb5 dxe5',
  // French, Caro-Kann, Scandinavian
  'e4 e6 d4 d5 Nc3 Nf6 Bg5 Be7 e5 Nfd7 Bxe7 Qxe7 f4 O-O Nf3 c5',
  'e4 e6 d4 d5 Nd2 Nf6 e5 Nfd7 Bd3 c5 c3 Nc6 Ne2 cxd4 cxd4 f6',
  'e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5 Ng3 Bg6 h4 h6 Nf3 Nd7 h5 Bh7',
  'e4 c6 d4 d5 e5 Bf5 Nf3 e6 Be2 c5 Be3 Nd7 O-O Ne7',
  'e4 d5 exd5 Qxd5 Nc3 Qa5 d4 Nf6 Nf3 c6 Bc4 Bf5 Bd2 e6',
  // Queen's pawn
  'd4 d5 c4 e6 Nc3 Nf6 Bg5 Be7 e3 O-O Nf3 h6 Bh4 b6 cxd5 Nxd5',
  'd4 d5 c4 e6 Nc3 Nf6 Nf3 Be7 Bg5 O-O e3 Nbd7 Rc1 c6 Bd3 dxc4',
  'd4 d5 c4 c6 Nf3 Nf6 Nc3 dxc4 a4 Bf5 e3 e6 Bxc4 Bb4 O-O Nbd7',
  'd4 d5 c4 dxc4 Nf3 Nf6 e3 e6 Bxc4 c5 O-O a6 Qe2 b5 Bb3 Bb7',
  'd4 d5 Nf3 Nf6 Bf4 e6 e3 c5 c3 Nc6 Nbd2 Bd6 Bg3 O-O Bd3 b6',
  'd4 d5 Bf4 Nf6 e3 e6 Nf3 Bd6 Bg3 O-O Nbd2 c5 c3 Nc6 Bd3 b6',
  // Indian defences
  'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2 e5 O-O Nc6 d5 Ne7',
  'd4 Nf6 c4 e6 Nc3 Bb4 e3 O-O Bd3 d5 Nf3 c5 O-O Nc6 a3 Bxc3',
  'd4 Nf6 c4 e6 Nf3 b6 g3 Bb7 Bg2 Be7 O-O O-O Nc3 Ne4 Qc2 Nxc3',
  'd4 Nf6 c4 e6 Nf3 d5 Nc3 Be7 Bg5 h6 Bh4 O-O e3 Ne4 Bxe7 Qxe7',
  // Flank openings
  'Nf3 d5 g3 Nf6 Bg2 e6 O-O Be7 d3 O-O Nbd2 c5 e4 Nc6',
  'Nf3 Nf6 c4 g6 Nc3 Bg7 e4 d6 d4 O-O Be2 e5 O-O Nc6 d5 Ne7',
  'Nf3 d5 d4 Nf6 c4 e6 Nc3 Be7 Bg5 O-O e3 h6 Bh4 b6',
  'c4 e5 Nc3 Nf6 Nf3 Nc6 g3 d5 cxd5 Nxd5 Bg2 Nb6 O-O Be7 d3 O-O',
  'c4 Nf6 Nc3 e6 e4 d5 e5 d4 exf6 dxc3 bxc3 Qxf6 Nf3 Nc6',
  'c4 c5 Nf3 Nf6 Nc3 Nc6 g3 g6 Bg2 Bg7 O-O O-O d4 cxd4',
];

Map<String, Set<String>>? _table;

String _key(Position pos) => pos.toFen().split(' ').take(2).join(' ');

Map<String, Set<String>> _build() {
  final table = <String, Set<String>>{};
  for (final line in _lines) {
    var pos = Position.start();
    for (final token in line.split(' ')) {
      final move = _find(pos, token);
      if (move == null) {
        throw StateError('Opening book: "$token" is not legal in "$line"');
      }
      (table[_key(pos)] ??= {}).add(move.uci);
      pos = pos.makeMove(move);
    }
  }
  return table;
}

Move? _find(Position pos, String token) {
  for (final m in pos.legalMoves()) {
    if (san(pos, m).replaceAll(RegExp('[+#]'), '') == token.replaceAll(RegExp('[+#]'), '')) return m;
  }
  return null;
}

/// Number of half-moves played so far in the game that led to [pos].
int plyOf(Position pos) => (pos.fullmove - 1) * 2 + (pos.turn == black ? 1 : 0);

/// A random book move for [pos], or null when the position is out of book or
/// more than [maxPlies] half-moves deep.
Move? bookMove(Position pos, int maxPlies, Random random) {
  if (plyOf(pos) >= maxPlies) return null;
  final uci = (_table ??= _build())[_key(pos)];
  if (uci == null) return null;
  final moves = pos.legalMoves().where((m) => uci.contains(m.uci)).toList();
  if (moves.isEmpty) return null;
  return moves[random.nextInt(moves.length)];
}

/// Every book position, for tests.
Map<String, Set<String>> bookTable() => _table ??= _build();
