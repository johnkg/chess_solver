import 'explainer.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'san.dart';
import 'search.dart';

/// A move this much worse than the best one (centipawns) is a mistake.
const int mistakeThreshold = 150;

enum MistakeKind { missesMate, allowsMate, losesMaterial }

/// Why a played move is bad: what it missed or allowed, in plain words.
class Mistake {
  final MistakeKind kind;
  final Move played;
  final Move best;

  /// The opponent's best answer to [played]; null for [MistakeKind.missesMate].
  final Move? reply;

  /// How much worse [played] is than [best], centipawns.
  final int loss;

  final String text;

  const Mistake({
    required this.kind,
    required this.played,
    required this.best,
    required this.reply,
    required this.loss,
    required this.text,
  });

  @override
  String toString() => text;
}

/// Score of every legal move at [depth] plies, for the side to move.
List<(Move, int)> scoreMoves(Position pos, int depth) => [
      for (final m in pos.legalMoves())
        (
          m,
          -negamax(pos.makeMove(m), depth - 1, -mateScore - 1, mateScore + 1, 1),
        ),
    ];

/// Null if [played] is fine; otherwise why it is bad. [played] must be a
/// legal move in [pos].
Mistake? explainMistake(Position pos, Move played, {int depth = 3}) {
  final scored = scoreMoves(pos, depth);
  var bestEntry = scored.first;
  for (final e in scored) {
    if (e.$2 > bestEntry.$2) bestEntry = e;
  }
  final best = bestEntry.$1;
  final bestScore = bestEntry.$2;
  final playedScore = scored.firstWhere((e) => e.$1 == played).$2;
  final loss = bestScore - playedScore;
  final s = pos.turn;
  final next = pos.makeMove(played);

  final MistakeKind kind;
  if (isMateScore(bestScore) &&
      bestScore > 0 &&
      !(isMateScore(playedScore) && playedScore > 0)) {
    kind = MistakeKind.missesMate;
  } else if (isMateScore(playedScore) && playedScore < 0) {
    kind = MistakeKind.allowsMate;
  } else if (loss >= mistakeThreshold) {
    kind = MistakeKind.losesMaterial;
  } else {
    return null;
  }

  final name = san(pos, played);
  final bestName = san(pos, best);
  final better = explainVerified(pos, best);
  final betterText = better.isEmpty ? '' : better.first.text;

  Move? reply;
  String reason;
  if (kind == MistakeKind.missesMate) {
    reason = '$name misses a forced mate: $bestName.';
  } else {
    reply = bestMove(next, depth - 1)!.move;
    final replyName = san(next, reply);
    final opp = colorName(1 - s);
    if (kind == MistakeKind.allowsMate) {
      reason = '$name allows $replyName, checkmate.';
    } else {
      final why = explainVerified(next, reply);
      final detail =
          why.isEmpty ? 'That leaves $opp clearly better.' : why.first.text;
      reason = '$name is a mistake: $opp replies $replyName. $detail';
    }
  }

  var text = reason;
  if (kind != MistakeKind.missesMate) text += ' Better was $bestName.';
  if (betterText.isNotEmpty) text += ' $betterText';

  return Mistake(
    kind: kind,
    played: played,
    best: best,
    reply: reply,
    loss: loss,
    text: text,
  );
}
