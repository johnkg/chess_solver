import 'move.dart';
import 'piece.dart';
import 'position.dart';

const List<String> _letters = ['', '', 'N', 'B', 'R', 'Q', 'K'];

/// Standard algebraic notation for [m] in [pos]: "e4", "Nbd2", "exd5",
/// "O-O", "e8=Q+", "Qxf7#".
String san(Position pos, Move m) {
  String core;
  if (m.flag == Move.castleKing) {
    core = 'O-O';
  } else if (m.flag == Move.castleQueen) {
    core = 'O-O-O';
  } else {
    final ty = pieceType(pos.squares[m.from]);
    final capture =
        pos.squares[m.to] != empty || m.flag == Move.enPassant;
    final fileLetter = String.fromCharCode(97 + fileOf(m.from));

    if (ty == pawn) {
      core = '${capture ? '${fileLetter}x' : ''}${squareName(m.to)}';
      if (m.promotion != 0) core += '=${_letters[m.promotion]}';
    } else {
      final others = [
        for (final o in pos.legalMoves())
          if (o.to == m.to &&
              o.from != m.from &&
              pieceType(pos.squares[o.from]) == ty)
            o,
      ];
      var dis = '';
      if (others.isNotEmpty) {
        final sameFile = others.any((o) => fileOf(o.from) == fileOf(m.from));
        final sameRank = others.any((o) => rankOf(o.from) == rankOf(m.from));
        if (!sameFile) {
          dis = fileLetter;
        } else if (!sameRank) {
          dis = '${rankOf(m.from) + 1}';
        } else {
          dis = squareName(m.from);
        }
      }
      core = '${_letters[ty]}$dis${capture ? 'x' : ''}${squareName(m.to)}';
    }
  }

  final next = pos.makeMove(m);
  if (next.inCheck) core += next.legalMoves().isEmpty ? '#' : '+';
  return core;
}
