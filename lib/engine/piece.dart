/// Piece and colour encoding. Pure Dart, no Flutter imports.
///
/// A piece is an int: `type | (color << 3)`. `0` means an empty square.
library;

const int empty = 0;

const int pawn = 1;
const int knight = 2;
const int bishop = 3;
const int rook = 4;
const int queen = 5;
const int king = 6;

const int white = 0;
const int black = 1;

int makePiece(int type, int color) => type | (color << 3);
int pieceType(int piece) => piece & 7;
int pieceColor(int piece) => piece >> 3;

const String _whiteChars = ' PNBRQK';
const String _blackChars = ' pnbrqk';

/// FEN letter for a piece ("P" white pawn, "n" black knight, ...).
String pieceChar(int piece) {
  final t = pieceType(piece);
  return pieceColor(piece) == white ? _whiteChars[t] : _blackChars[t];
}

/// Piece for a FEN letter, or `null` if the letter is not a piece.
int? pieceFromChar(String ch) {
  final w = _whiteChars.indexOf(ch);
  if (w > 0) return makePiece(w, white);
  final b = _blackChars.indexOf(ch);
  if (b > 0) return makePiece(b, black);
  return null;
}

/// Square index: a1 = 0, b1 = 1, ... h1 = 7, a2 = 8, ... h8 = 63.
int squareOf(int rank, int file) => rank * 8 + file;
int rankOf(int square) => square >> 3;
int fileOf(int square) => square & 7;

String squareName(int square) =>
    '${String.fromCharCode(97 + fileOf(square))}${rankOf(square) + 1}';

/// Square for a name like "e4", or `-1` if the name is not valid.
int parseSquare(String name) {
  if (name.length != 2) return -1;
  final f = name.codeUnitAt(0) - 97;
  final r = name.codeUnitAt(1) - 49;
  if (f < 0 || f > 7 || r < 0 || r > 7) return -1;
  return squareOf(r, f);
}

/// Standard material values in pawns (king has no value).
int pieceValue(int type) {
  switch (type) {
    case pawn:
      return 1;
    case knight:
    case bishop:
      return 3;
    case rook:
      return 5;
    case queen:
      return 9;
    default:
      return 0;
  }
}

const List<String> _typeNames = [
  '', 'pawn', 'knight', 'bishop', 'rook', 'queen', 'king', //
];

/// "knight", "queen", ... for a piece type (not a piece).
String pieceName(int type) => _typeNames[type];

String colorName(int color) => color == white ? 'White' : 'Black';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
