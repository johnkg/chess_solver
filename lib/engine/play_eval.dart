import 'piece.dart';
import 'position.dart';

/// Evaluation used by the computer opponent only. The teaching text keeps
/// using the named terms in `eval.dart`; this one is tuned to pick good moves:
/// material, piece-square tables, pawn structure, bishop pair, rooks on open
/// files and king safety.

/// Material value in centipawns, indexed by piece type (the king has none).
const List<int> centipawnValue = [0, 100, 320, 330, 500, 900, 0];

// Piece-square tables, written as the board is drawn: first row is rank 8,
// from White's side. Values in centipawns.
const List<int> _pawnTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _knightTable = [
  -50, -40, -30, -30, -30, -30, -40, -50, //
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _bishopTable = [
  -20, -10, -10, -10, -10, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _rookTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _queenTable = [
  -20, -10, -10, -5, -5, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _kingMiddle = [
  -30, -40, -40, -50, -50, -40, -40, -30, //
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const List<int> _kingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];
const List<List<int>> _tables = [
  [], _pawnTable, _knightTable, _bishopTable, _rookTable, _queenTable, _kingMiddle,
];

/// Bonus for a passed pawn by how far it has advanced (relative rank 0..7).
const List<int> _passedPawnBonus = [0, 10, 15, 25, 45, 80, 140, 0];

const int _doubledPawnPenalty = 15; // per extra pawn on a file
const int _isolatedPawnPenalty = 12; // per file with pawns and no neighbours
const int _bishopPairBonus = 30;
const int _rookOpenFileBonus = 20; // no pawns of either colour on its file
const int _rookSemiOpenFileBonus = 10; // only the enemy has pawns there
const int _pawnShieldBonus = 12; // per pawn right in front of a castled king
const int _tempoBonus = 10; // having the move

/// Non-pawn material (both sides) at which the endgame blend begins; below
/// it the king table fades from middlegame to endgame.
const int _fullMiddlegameMaterial = 6200;

/// The pawn shield counts only while the game is still this far from the
/// endgame (0 = full middlegame, 1 = bare endgame).
const double _shieldMaxEndgameBlend = 0.5;

/// +1 for White, -1 for Black: scores are kept as White minus Black.
int _sign(int color) => color == white ? 1 : -1;

/// Rank counted from [color]'s own back rank (0) to the far side (7).
int _relativeRank(int color, int rank) => color == white ? rank : boardSize - 1 - rank;

/// Index into a table drawn from White's side with rank 8 first.
int _tableIndex(int color, int square) =>
    (boardSize - 1 - _relativeRank(color, rankOf(square))) * boardSize + fileOf(square);

/// What one pass over the board finds, for the terms that need it.
class _Census {
  int placement = 0; // material and piece-square values, White minus Black
  int nonPawnMaterial = 0;
  final List<List<int>> pawnsOnFile = [
    List<int>.filled(boardSize, 0),
    List<int>.filled(boardSize, 0),
  ];
  final List<int> bishops = [0, 0];
  final List<int> kings = [-1, -1];
  final List<int> rooks = [];
}

_Census _countPieces(List<int> squares) {
  final census = _Census();
  for (var square = 0; square < boardSquares; square++) {
    final piece = squares[square];
    if (piece == empty) continue;
    final color = pieceColor(piece);
    final type = pieceType(piece);
    var value = centipawnValue[type];
    if (type == king) {
      census.kings[color] = square;
    } else {
      value += _tables[type][_tableIndex(color, square)];
      if (type == pawn) {
        census.pawnsOnFile[color][fileOf(square)]++;
      } else {
        census.nonPawnMaterial += centipawnValue[type];
        if (type == bishop) census.bishops[color]++;
        if (type == rook) census.rooks.add(square);
      }
    }
    census.placement += _sign(color) * value;
  }
  return census;
}

/// How far the game is into the endgame: 0 with all pieces, 1 with none.
double _endgameBlend(_Census census) =>
    (1 - census.nonPawnMaterial / _fullMiddlegameMaterial).clamp(0.0, 1.0);

/// Kings: the middlegame table fades into the endgame table as pieces come off.
int _kingPlacement(_Census census, double endgame) {
  var score = 0;
  for (final color in [white, black]) {
    final king = census.kings[color];
    if (king < 0) continue;
    final i = _tableIndex(color, king);
    final value = (_kingMiddle[i] * (1 - endgame) + _kingEnd[i] * endgame).round();
    score += _sign(color) * value;
  }
  return score;
}

/// Doubled and isolated pawns.
int _pawnStructure(_Census census) {
  var score = 0;
  for (final color in [white, black]) {
    final pawns = census.pawnsOnFile[color];
    for (var file = 0; file < boardSize; file++) {
      if (pawns[file] == 0) continue;
      if (pawns[file] > 1) score -= _sign(color) * _doubledPawnPenalty * (pawns[file] - 1);
      final left = file > 0 ? pawns[file - 1] : 0;
      final right = file < boardSize - 1 ? pawns[file + 1] : 0;
      if (left == 0 && right == 0) score -= _sign(color) * _isolatedPawnPenalty;
    }
  }
  return score;
}

int _passedPawns(List<int> squares) {
  var score = 0;
  for (var square = 0; square < boardSquares; square++) {
    final piece = squares[square];
    if (piece == empty || pieceType(piece) != pawn) continue;
    final color = pieceColor(piece);
    if (_isPassed(squares, square, color)) {
      score += _sign(color) * _passedPawnBonus[_relativeRank(color, rankOf(square))];
    }
  }
  return score;
}

int _bishopPair(_Census census) {
  var score = 0;
  for (final color in [white, black]) {
    if (census.bishops[color] >= 2) score += _sign(color) * _bishopPairBonus;
  }
  return score;
}

int _rooksOnOpenFiles(List<int> squares, _Census census) {
  var score = 0;
  for (final square in census.rooks) {
    final color = pieceColor(squares[square]);
    final file = fileOf(square);
    final ownPawns = census.pawnsOnFile[color][file];
    final enemyPawns = census.pawnsOnFile[1 - color][file];
    if (ownPawns != 0) continue;
    score += _sign(color) * (enemyPawns == 0 ? _rookOpenFileBonus : _rookSemiOpenFileBonus);
  }
  return score;
}

/// Pawns in front of a king that is still on its back rank.
int _pawnShield(List<int> squares, _Census census) {
  var score = 0;
  for (final color in [white, black]) {
    final king = census.kings[color];
    if (king < 0) continue;
    final backRank = color == white ? 0 : boardSize - 1;
    if (rankOf(king) != backRank) continue;
    final forward = _sign(color);
    var shield = 0;
    for (var file = fileOf(king) - 1; file <= fileOf(king) + 1; file++) {
      if (file < 0 || file >= boardSize) continue;
      if (squares[squareOf(backRank + forward, file)] == makePiece(pawn, color)) shield++;
    }
    score += _sign(color) * _pawnShieldBonus * shield;
  }
  return score;
}

/// Score in centipawns from the side to move's point of view.
int playEval(Position pos) {
  final squares = pos.squares;
  final census = _countPieces(squares);
  final endgame = _endgameBlend(census);

  var score = census.placement +
      _kingPlacement(census, endgame) +
      _pawnStructure(census) +
      _passedPawns(squares) +
      _bishopPair(census) +
      _rooksOnOpenFiles(squares, census);
  if (endgame < _shieldMaxEndgameBlend) score += _pawnShield(squares, census);

  final fromMover = pos.turn == white ? score : -score;
  return fromMover + _tempoBonus;
}

/// True if no enemy pawn on this or a neighbouring file is ahead of the pawn
/// on [square].
bool _isPassed(List<int> squares, int square, int color) {
  final file = fileOf(square);
  final forward = _sign(color);
  final enemyPawn = makePiece(pawn, 1 - color);
  for (var rank = rankOf(square) + forward; rank >= 0 && rank < boardSize; rank += forward) {
    for (var f = file - 1; f <= file + 1; f++) {
      if (f < 0 || f >= boardSize) continue;
      if (squares[squareOf(rank, f)] == enemyPawn) return false;
    }
  }
  return true;
}
