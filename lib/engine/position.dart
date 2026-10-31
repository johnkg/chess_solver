import 'move.dart';
import 'piece.dart';

const int _castleWhiteKing = 1;
const int _castleWhiteQueen = 2;
const int _castleBlackKing = 4;
const int _castleBlackQueen = 8;

const List<List<int>> _knightSteps = [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2], //
];
const List<List<int>> _kingSteps = [
  [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1], //
];
const List<List<int>> _bishopDirs = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];
const List<List<int>> _rookDirs = [
  [1, 0], [-1, 0], [0, 1], [0, -1], //
];
const List<int> _promotionTypes = [queen, rook, bishop, knight];

/// An immutable chess position: board, side to move, castling rights,
/// en passant square and move counters.
class Position {
  static const String startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// 64 squares, a1 = 0 ... h8 = 63. Each entry is a piece or [empty].
  /// Treat as read-only: positions are immutable.
  final List<int> squares;

  /// [white] or [black].
  final int turn;

  /// Bit set: 1 white kingside, 2 white queenside, 4 black kingside,
  /// 8 black queenside.
  final int castling;

  /// Square a pawn can capture onto en passant, or `-1`.
  final int epSquare;

  final int halfmove;
  final int fullmove;

  Position._(this.squares, this.turn, this.castling, this.epSquare,
      this.halfmove, this.fullmove);

  factory Position.start() => Position.fromFen(startFen);

  /// Parses a FEN string. Throws [FormatException] if it is malformed.
  factory Position.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw FormatException('FEN needs at least board and side to move', fen);
    }

    final ranks = parts[0].split('/');
    if (ranks.length != 8) {
      throw FormatException('FEN board needs 8 ranks', fen);
    }
    final squares = List<int>.filled(64, empty);
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var file = 0;
      for (final ch in ranks[i].split('')) {
        final skip = int.tryParse(ch);
        if (skip != null) {
          if (skip < 1 || skip > 8) {
            throw FormatException('Bad empty-square count "$ch"', fen);
          }
          file += skip;
        } else {
          final piece = pieceFromChar(ch);
          if (piece == null || file > 7) {
            throw FormatException('Bad piece "$ch" in FEN', fen);
          }
          squares[squareOf(rank, file)] = piece;
          file++;
        }
      }
      if (file != 8) {
        throw FormatException('Rank ${rank + 1} does not have 8 files', fen);
      }
    }

    final int turn;
    switch (parts[1]) {
      case 'w':
        turn = white;
      case 'b':
        turn = black;
      default:
        throw FormatException('Side to move must be w or b', fen);
    }

    var castling = 0;
    if (parts.length > 2 && parts[2] != '-') {
      for (final ch in parts[2].split('')) {
        switch (ch) {
          case 'K':
            castling |= _castleWhiteKing;
          case 'Q':
            castling |= _castleWhiteQueen;
          case 'k':
            castling |= _castleBlackKing;
          case 'q':
            castling |= _castleBlackQueen;
          default:
            throw FormatException('Bad castling flag "$ch"', fen);
        }
      }
    }

    var ep = -1;
    if (parts.length > 3 && parts[3] != '-') {
      ep = parseSquare(parts[3]);
      if (ep < 0) throw FormatException('Bad en passant square', fen);
    }

    final halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    final fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

    return Position._(squares, turn, castling, ep, halfmove, fullmove);
  }

  /// Identity of the position for repetition: placement, side to move,
  /// castling rights and en passant square (no move counters).
  String get repetitionKey => toFen().split(' ').take(4).join(' ');

  String toFen() {
    final rows = <String>[];
    for (var rank = 7; rank >= 0; rank--) {
      final row = StringBuffer();
      var gap = 0;
      for (var file = 0; file < 8; file++) {
        final p = squares[squareOf(rank, file)];
        if (p == empty) {
          gap++;
        } else {
          if (gap > 0) row.write(gap);
          gap = 0;
          row.write(pieceChar(p));
        }
      }
      if (gap > 0) row.write(gap);
      rows.add(row.toString());
    }

    final rights = StringBuffer();
    if (castling & _castleWhiteKing != 0) rights.write('K');
    if (castling & _castleWhiteQueen != 0) rights.write('Q');
    if (castling & _castleBlackKing != 0) rights.write('k');
    if (castling & _castleBlackQueen != 0) rights.write('q');

    final side = turn == white ? 'w' : 'b';
    final cast = rights.isEmpty ? '-' : rights.toString();
    final ep = epSquare < 0 ? '-' : squareName(epSquare);
    return '${rows.join('/')} $side $cast $ep $halfmove $fullmove';
  }

  /// Plain-text board, rank 8 at the top. Handy in tests and the CLI.
  String pretty() {
    final out = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      out.write('${rank + 1} ');
      for (var file = 0; file < 8; file++) {
        final p = squares[squareOf(rank, file)];
        out.write(p == empty ? '. ' : '${pieceChar(p)} ');
      }
      out.writeln();
    }
    out.write('  a b c d e f g h');
    return out.toString();
  }

  /// Square of [color]'s king, or `-1` if there is none.
  int kingSquare(int color) {
    final target = makePiece(king, color);
    for (var sq = 0; sq < 64; sq++) {
      if (squares[sq] == target) return sq;
    }
    return -1;
  }

  /// True if any piece of colour [by] attacks [sq].
  bool isAttacked(int sq, int by) {
    final r = rankOf(sq);
    final f = fileOf(sq);

    // Pawns attack diagonally forward, so look one rank back from [sq].
    final pr = by == white ? r - 1 : r + 1;
    if (pr >= 0 && pr < 8) {
      final pawnPiece = makePiece(pawn, by);
      if (f > 0 && squares[squareOf(pr, f - 1)] == pawnPiece) return true;
      if (f < 7 && squares[squareOf(pr, f + 1)] == pawnPiece) return true;
    }

    final knightPiece = makePiece(knight, by);
    for (final d in _knightSteps) {
      final nr = r + d[0];
      final nf = f + d[1];
      if (nr < 0 || nr > 7 || nf < 0 || nf > 7) continue;
      if (squares[squareOf(nr, nf)] == knightPiece) return true;
    }

    final kingPiece = makePiece(king, by);
    for (final d in _kingSteps) {
      final nr = r + d[0];
      final nf = f + d[1];
      if (nr < 0 || nr > 7 || nf < 0 || nf > 7) continue;
      if (squares[squareOf(nr, nf)] == kingPiece) return true;
    }

    if (_rayHits(r, f, _bishopDirs, makePiece(bishop, by), makePiece(queen, by))) {
      return true;
    }
    if (_rayHits(r, f, _rookDirs, makePiece(rook, by), makePiece(queen, by))) {
      return true;
    }
    return false;
  }

  bool _rayHits(int r, int f, List<List<int>> dirs, int a, int b) {
    for (final d in dirs) {
      var nr = r + d[0];
      var nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final p = squares[squareOf(nr, nf)];
        if (p != empty) {
          if (p == a || p == b) return true;
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
    return false;
  }

  /// True if the side to move is in check.
  bool get inCheck {
    final k = kingSquare(turn);
    return k >= 0 && isAttacked(k, 1 - turn);
  }

  /// Moves that follow piece movement rules but may leave the own king
  /// in check. Use [legalMoves] unless you need the raw list.
  List<Move> pseudoLegalMoves() {
    final moves = <Move>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = squares[sq];
      if (p == empty || pieceColor(p) != turn) continue;
      switch (pieceType(p)) {
        case pawn:
          _pawnMoves(sq, moves);
        case knight:
          _stepMoves(sq, _knightSteps, moves);
        case bishop:
          _slideMoves(sq, _bishopDirs, moves);
        case rook:
          _slideMoves(sq, _rookDirs, moves);
        case queen:
          _slideMoves(sq, _bishopDirs, moves);
          _slideMoves(sq, _rookDirs, moves);
        case king:
          _stepMoves(sq, _kingSteps, moves);
          _castlingMoves(moves);
      }
    }
    return moves;
  }

  void _stepMoves(int sq, List<List<int>> steps, List<Move> moves) {
    final r = rankOf(sq);
    final f = fileOf(sq);
    for (final d in steps) {
      final nr = r + d[0];
      final nf = f + d[1];
      if (nr < 0 || nr > 7 || nf < 0 || nf > 7) continue;
      final to = squareOf(nr, nf);
      final target = squares[to];
      if (target == empty || pieceColor(target) != turn) {
        moves.add(Move(sq, to));
      }
    }
  }

  void _slideMoves(int sq, List<List<int>> dirs, List<Move> moves) {
    final r = rankOf(sq);
    final f = fileOf(sq);
    for (final d in dirs) {
      var nr = r + d[0];
      var nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final to = squareOf(nr, nf);
        final target = squares[to];
        if (target == empty) {
          moves.add(Move(sq, to));
        } else {
          if (pieceColor(target) != turn) moves.add(Move(sq, to));
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
  }

  void _pawnMoves(int sq, List<Move> moves) {
    final r = rankOf(sq);
    final f = fileOf(sq);
    final dir = turn == white ? 1 : -1;
    final startRank = turn == white ? 1 : 6;
    final lastRank = turn == white ? 7 : 0;

    void add(int to, int flag) {
      if (rankOf(to) == lastRank) {
        for (final t in _promotionTypes) {
          moves.add(Move(sq, to, promotion: t));
        }
      } else {
        moves.add(Move(sq, to, flag: flag));
      }
    }

    if (r + dir < 0 || r + dir > 7) return; // pawn on last rank: no moves

    final one = squareOf(r + dir, f);
    if (squares[one] == empty) {
      add(one, Move.quiet);
      if (r == startRank) {
        final two = squareOf(r + 2 * dir, f);
        if (squares[two] == empty) add(two, Move.doublePush);
      }
    }

    for (final df in const [-1, 1]) {
      final nf = f + df;
      if (nf < 0 || nf > 7) continue;
      final to = squareOf(r + dir, nf);
      final target = squares[to];
      if (target != empty && pieceColor(target) != turn) {
        add(to, Move.quiet);
      } else if (target == empty && to == epSquare) {
        moves.add(Move(sq, to, flag: Move.enPassant));
      }
    }
  }

  void _castlingMoves(List<Move> moves) {
    final base = turn == white ? 0 : 56;
    final them = 1 - turn;
    final kingPiece = makePiece(king, turn);
    final rookPiece = makePiece(rook, turn);
    if (squares[base + 4] != kingPiece) return;

    final kingSide = turn == white ? _castleWhiteKing : _castleBlackKing;
    final queenSide = turn == white ? _castleWhiteQueen : _castleBlackQueen;

    if (castling & kingSide != 0 &&
        squares[base + 7] == rookPiece &&
        squares[base + 5] == empty &&
        squares[base + 6] == empty &&
        !isAttacked(base + 4, them) &&
        !isAttacked(base + 5, them) &&
        !isAttacked(base + 6, them)) {
      moves.add(Move(base + 4, base + 6, flag: Move.castleKing));
    }

    if (castling & queenSide != 0 &&
        squares[base] == rookPiece &&
        squares[base + 1] == empty &&
        squares[base + 2] == empty &&
        squares[base + 3] == empty &&
        !isAttacked(base + 4, them) &&
        !isAttacked(base + 3, them) &&
        !isAttacked(base + 2, them)) {
      moves.add(Move(base + 4, base + 2, flag: Move.castleQueen));
    }
  }

  /// Position after playing [m]. Does not check that [m] is legal.
  Position makeMove(Move m) {
    final s = List<int>.from(squares);
    final piece = s[m.from];
    final captured = s[m.to];

    s[m.to] = m.promotion != 0 ? makePiece(m.promotion, turn) : piece;
    s[m.from] = empty;

    if (m.flag == Move.enPassant) {
      s[turn == white ? m.to - 8 : m.to + 8] = empty;
    } else if (m.flag == Move.castleKing) {
      s[m.from + 3] = empty;
      s[m.from + 1] = makePiece(rook, turn);
    } else if (m.flag == Move.castleQueen) {
      s[m.from - 4] = empty;
      s[m.from - 1] = makePiece(rook, turn);
    }

    var rights = castling;
    if (pieceType(piece) == king) {
      rights &= turn == white
          ? ~(_castleWhiteKing | _castleWhiteQueen)
          : ~(_castleBlackKing | _castleBlackQueen);
    }
    for (final sq in [m.from, m.to]) {
      if (sq == 0) rights &= ~_castleWhiteQueen;
      if (sq == 7) rights &= ~_castleWhiteKing;
      if (sq == 56) rights &= ~_castleBlackQueen;
      if (sq == 63) rights &= ~_castleBlackKing;
    }

    final ep = m.flag == Move.doublePush ? (m.from + m.to) >> 1 : -1;
    final resetClock = pieceType(piece) == pawn ||
        captured != empty ||
        m.flag == Move.enPassant;

    return Position._(
      s,
      1 - turn,
      rights,
      ep,
      resetClock ? 0 : halfmove + 1,
      turn == black ? fullmove + 1 : fullmove,
    );
  }

  /// Same position with the other side to move (a "null move"). Used to
  /// measure what a move gains compared with doing nothing.
  Position passTurn() =>
      Position._(List<int>.from(squares), 1 - turn, castling, -1, halfmove, fullmove);

  /// All legal moves for the side to move.
  List<Move> legalMoves() {
    final legal = <Move>[];
    for (final m in pseudoLegalMoves()) {
      final next = makeMove(m);
      final k = next.kingSquare(turn);
      if (k < 0 || !next.isAttacked(k, 1 - turn)) legal.add(m);
    }
    return legal;
  }

  bool get isCheckmate => inCheck && legalMoves().isEmpty;
  bool get isStalemate => !inCheck && legalMoves().isEmpty;

  /// Counts leaf positions after [depth] plies. Used to prove move
  /// generation correct against published counts.
  int perft(int depth) {
    if (depth == 0) return 1;
    final moves = legalMoves();
    if (depth == 1) return moves.length;
    var nodes = 0;
    for (final m in moves) {
      nodes += makeMove(m).perft(depth - 1);
    }
    return nodes;
  }
}
