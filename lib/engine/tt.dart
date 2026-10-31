import 'dart:math';
import 'dart:typed_data';

import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'search.dart' show mateScore;

/// What a stored score says about the true value.
const int ttExact = 0;
const int ttLower = 1; // true value >= score (a beta cutoff)
const int ttUpper = 2; // true value <= score (failed low)

/// Two independent 30-bit hashes of a position. Kept below 2^31 so the bit
/// operations behave the same on the web, where ints are 32-bit in `^`.
class _Zobrist {
  _Zobrist() {
    final rng = Random(0x5eed);
    int next() => rng.nextInt(1 << 30);
    for (var i = 0; i < pieces.length; i++) {
      pieces[i] = next();
      pieces2[i] = next();
    }
    for (var i = 0; i < castling.length; i++) {
      castling[i] = next();
      castling2[i] = next();
    }
    for (var i = 0; i < ep.length; i++) {
      ep[i] = next();
      ep2[i] = next();
    }
    side = next();
    side2 = next();
  }

  // Index: piece (0..15) * 64 + square.
  final List<int> pieces = List<int>.filled(16 * 64, 0);
  final List<int> pieces2 = List<int>.filled(16 * 64, 0);
  final List<int> castling = List<int>.filled(16, 0);
  final List<int> castling2 = List<int>.filled(16, 0);
  final List<int> ep = List<int>.filled(65, 0);
  final List<int> ep2 = List<int>.filled(65, 0);
  late final int side;
  late final int side2;
}

final _Zobrist _z = _Zobrist();

/// Transposition table: remembers what a search learned about a position so
/// that the same position reached by another move order, or at the next
/// iteration, is not searched again, and so its best move can be tried first.
class TranspositionTable {
  TranspositionTable(int bits)
      : _mask = (1 << bits) - 1,
        _check = Int32List(1 << bits),
        _score = Int32List(1 << bits),
        _meta = Int32List(1 << bits);

  final int _mask;
  final Int32List _check;
  final Int32List _score;
  // depth (7 bits) | flag (2 bits) << 7 | move << 9
  final Int32List _meta;

  /// Hashes of [pos]: the first picks the slot, the second verifies it.
  static (int, int) hashOf(Position pos) {
    var a = 0;
    var b = 0;
    final sq = pos.squares;
    for (var i = 0; i < 64; i++) {
      final p = sq[i];
      if (p != empty) {
        final k = p * 64 + i;
        a ^= _z.pieces[k];
        b ^= _z.pieces2[k];
      }
    }
    a ^= _z.castling[pos.castling] ^ _z.ep[pos.epSquare + 1];
    b ^= _z.castling2[pos.castling] ^ _z.ep2[pos.epSquare + 1];
    if (pos.turn == black) {
      a ^= _z.side;
      b ^= _z.side2;
    }
    return (a, b);
  }

  static int _pack(Move? m) => m == null
      ? 0
      : (m.from | (m.to << 6) | (m.promotion << 12) | (m.flag << 15)) + 1;

  /// True if [m] is the move packed into [packed].
  static bool sameMove(int packed, Move m) => packed != 0 && packed == _pack(m);

  /// Mate scores are stored relative to the node, not the root.
  static int _toTable(int score, int ply) {
    if (score > mateScore - 1000) return score + ply;
    if (score < -mateScore + 1000) return score - ply;
    return score;
  }

  static int _fromTable(int score, int ply) {
    if (score > mateScore - 1000) return score - ply;
    if (score < -mateScore + 1000) return score + ply;
    return score;
  }

  /// Slot index for a probe, or -1 when [hash2] is not stored there.
  int find(int hash1, int hash2) {
    final i = hash1 & _mask;
    return _check[i] == hash2 + 1 ? i : -1;
  }

  int depthAt(int i) => _meta[i] & 127;
  int flagAt(int i) => (_meta[i] >> 7) & 3;
  int moveAt(int i) => _meta[i] >> 9;
  int scoreAt(int i, int ply) => _fromTable(_score[i], ply);

  void store(
    int hash1,
    int hash2,
    int depth,
    int score,
    int flag,
    Move? move,
    int ply,
  ) {
    final i = hash1 & _mask;
    final old = _check[i];
    // Keep a deeper result for the same position; otherwise replace.
    if (old == hash2 + 1 && depthAt(i) > depth) {
      // Still remember a move if we have none.
      if (moveAt(i) == 0 && move != null) {
        _meta[i] = (_meta[i] & 511) | (_pack(move) << 9);
      }
      return;
    }
    _check[i] = hash2 + 1;
    _score[i] = _toTable(score, ply);
    _meta[i] = min(depth, 127) | (flag << 7) | (_pack(move) << 9);
  }
}
