import 'piece.dart';

/// A move from one square to another.
///
/// Whether a move captures is read from the board, not stored here.
class Move {
  static const int quiet = 0;
  static const int doublePush = 1;
  static const int castleKing = 2;
  static const int castleQueen = 3;
  static const int enPassant = 4;

  final int from;
  final int to;

  /// Piece type the pawn becomes, or `0` when this is not a promotion.
  final int promotion;

  /// One of [quiet], [doublePush], [castleKing], [castleQueen], [enPassant].
  final int flag;

  const Move(this.from, this.to, {this.promotion = 0, this.flag = quiet});

  /// Long algebraic form used by UCI engines: "e2e4", "e7e8q".
  String get uci {
    final promo = promotion == 0 ? '' : pieceChar(makePiece(promotion, black));
    return '${squareName(from)}${squareName(to)}$promo';
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion &&
      other.flag == flag;

  @override
  int get hashCode => Object.hash(from, to, promotion, flag);

  @override
  String toString() => uci;
}
