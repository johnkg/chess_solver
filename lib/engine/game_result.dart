import 'position.dart';

/// How a finished game scored for the human: 1 win, 0.5 draw, 0 loss.
/// Null while the game goes on. [drawn] is true when a rule ended it in a draw
/// (fifty moves, repetition, too few pieces); [flagged] is the colour that ran
/// out of time, if any.
double? playerScore({
  required Position pos,
  required int player,
  required bool drawn,
  required bool resigned,
  required int? flagged,
}) {
  if (resigned) return 0;
  if (flagged != null) return flagged == player ? 0 : 1;
  if (pos.isCheckmate) return pos.turn == player ? 0 : 1;
  final over = pos.legalMoves().isEmpty || drawn;
  return over ? 0.5 : null;
}

/// "Rating 1215 (+15)." for a rating that moved from [before] to [after].
String ratingChangeNote(int before, int after) {
  final change = after - before;
  return 'Rating $after (${change >= 0 ? '+' : ''}$change).';
}
