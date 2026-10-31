import 'dart:math';
import 'dart:typed_data';

import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'search.dart' show isMateScore;

/// What a stored score says about the position's true value.
enum ScoreBound {
  /// The score is the value.
  exact,

  /// The value is at least the score (a beta cutoff).
  lower,

  /// The value is at most the score (failed low).
  upper,
}

/// Bits of each Zobrist hash. Below 31 so the bit operations behave the same
/// on the web, where `^` works on 32-bit values.
const int _hashBits = 30;
const int _zobristSeed = 0x5eed;

const int _pieceCodes = 16; // piece = type | color << 3
const int _castlingStates = 16; // four rights bits
const int _epStates = boardSquares + 1; // a square, or none

// Layout of one table entry's `meta` word: depth, then bound, then move.
const int _depthBits = 7;
const int _depthMask = (1 << _depthBits) - 1;
const int _boundBits = 2;
const int _boundMask = (1 << _boundBits) - 1;
const int _moveShift = _depthBits + _boundBits;

// Layout of a packed move: from, to, promotion piece, flag.
const int _squareBits = 6;
const int _promotionShift = 2 * _squareBits;
const int _promotionBits = 3;
const int _flagShift = _promotionShift + _promotionBits;

/// Two independent 30-bit hashes of a position. Kept below 2^31 so the bit
/// operations behave the same on the web, where ints are 32-bit in `^`.
class _Zobrist {
  _Zobrist() {
    final rng = Random(_zobristSeed);
    int next() => rng.nextInt(1 << _hashBits);
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

  // Index: piece * boardSquares + square.
  final List<int> pieces = List<int>.filled(_pieceCodes * boardSquares, 0);
  final List<int> pieces2 = List<int>.filled(_pieceCodes * boardSquares, 0);
  final List<int> castling = List<int>.filled(_castlingStates, 0);
  final List<int> castling2 = List<int>.filled(_castlingStates, 0);
  final List<int> ep = List<int>.filled(_epStates, 0);
  final List<int> ep2 = List<int>.filled(_epStates, 0);
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
  // depth | bound << _depthBits | move << _moveShift
  final Int32List _meta;

  /// Hashes of [pos]: the first picks the slot, the second verifies it.
  static (int, int) hashOf(Position pos) {
    var a = 0;
    var b = 0;
    final sq = pos.squares;
    for (var i = 0; i < boardSquares; i++) {
      final p = sq[i];
      if (p != empty) {
        final k = p * boardSquares + i;
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

  /// A move as one int, never 0 (0 means "no move").
  static int _pack(Move? m) => m == null
      ? 0
      : (m.from | (m.to << _squareBits) | (m.promotion << _promotionShift) | (m.flag << _flagShift)) + 1;

  /// True if [m] is the move packed into [packed].
  static bool sameMove(int packed, Move m) => packed != 0 && packed == _pack(m);

  /// Mate scores are stored relative to the node, not the root.
  static int _toTable(int score, int ply) {
    if (!isMateScore(score)) return score;
    return score > 0 ? score + ply : score - ply;
  }

  static int _fromTable(int score, int ply) {
    if (!isMateScore(score)) return score;
    return score > 0 ? score - ply : score + ply;
  }

  /// Slot index for a probe, or -1 when [hash2] is not stored there.
  int find(int hash1, int hash2) {
    final i = hash1 & _mask;
    return _check[i] == hash2 + 1 ? i : -1;
  }

  int depthAt(int i) => _meta[i] & _depthMask;
  ScoreBound boundAt(int i) => ScoreBound.values[(_meta[i] >> _depthBits) & _boundMask];
  int moveAt(int i) => _meta[i] >> _moveShift;
  int scoreAt(int i, int ply) => _fromTable(_score[i], ply);

  void store(
    int hash1,
    int hash2,
    int depth,
    int score,
    ScoreBound bound,
    Move? move,
    int ply,
  ) {
    final i = hash1 & _mask;
    final old = _check[i];
    // Keep a deeper result for the same position; otherwise replace.
    if (old == hash2 + 1 && depthAt(i) > depth) {
      // Still remember a move if we have none.
      if (moveAt(i) == 0 && move != null) {
        _meta[i] = (_meta[i] & ((1 << _moveShift) - 1)) | (_pack(move) << _moveShift);
      }
      return;
    }
    _check[i] = hash2 + 1;
    _score[i] = _toTable(score, ply);
    _meta[i] = min(depth, _depthMask) | (bound.index << _depthBits) | (_pack(move) << _moveShift);
  }
}
