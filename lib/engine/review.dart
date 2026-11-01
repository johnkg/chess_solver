import 'explainer.dart';
import 'insight.dart';
import 'mistakes.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'san.dart';

/// Key under which forced-mate misses are tracked (mate-in-2 and -3 puzzles
/// have no [Idea]).
const String mateKey = 'mate';

/// Tracking key for a puzzle or a missed idea.
String weakKey(Idea? idea) => idea?.name ?? mateKey;

/// One of the player's moves, judged.
class ReviewEntry {
  /// Plies played in the game before this move.
  final int ply;

  /// "12." for White, "12..." for Black.
  final String number;
  final String san;

  /// The position before the move, as FEN: the snapshot the review shows.
  final String fen;

  /// Null when the move was fine.
  final Mistake? mistake;

  /// What the player should have found, as a [weakKey]; null if the move was
  /// fine or the lesson is not one we can drill (for example allowing mate).
  final String? missedKey;

  const ReviewEntry({
    required this.ply,
    required this.number,
    required this.san,
    required this.fen,
    required this.mistake,
    required this.missedKey,
  });

  bool get isMistake => mistake != null;
}

/// Judges [played] in [before]. [mistake] is the result of [explainMistake] for
/// this move (null: fine). [ply] is how many plies were played
/// before this move.
ReviewEntry reviewMove(
  Position before,
  Move played, {
  required int ply,
  required Mistake? mistake,
}) {
  final m = mistake;
  String? key;
  if (m != null && m.kind != MistakeKind.allowsMate) {
    final why = explainVerified(before, m.best);
    key = why.isNotEmpty
        ? weakKey(why.first.idea)
        : (m.kind == MistakeKind.missesMate ? mateKey : null);
  }
  return ReviewEntry(
    ply: ply,
    number: before.turn == white ? '${before.fullmove}.' : '${before.fullmove}...',
    san: san(before, played),
    fen: before.toFen(),
    mistake: m,
    missedKey: key,
  );
}

/// One line on how the game went.
String reviewSummary(List<ReviewEntry> entries) {
  if (entries.isEmpty) return 'No moves to review yet.';
  final bad = entries.where((e) => e.isMistake).length;
  final good = entries.length - bad;
  final moves = entries.length == 1 ? '1 move' : '${entries.length} moves';
  if (bad == 0) return 'You played $moves, all of them sound.';
  return 'You played $moves: $good sound, $bad '
      '${bad == 1 ? 'mistake' : 'mistakes'}.';
}

/// Centipawns of loss at which a single move counts as fully lost.
const int _maxLossCounted = 300;

/// A rough 0-100 score for how closely the moves followed the best ones: each
/// move loses a share of its centipawn loss (capped at [_maxLossCounted]), so one blunder
/// hurts more than a few inaccuracies. Null when there are no moves.
int? reviewAccuracy(List<ReviewEntry> entries) {
  if (entries.isEmpty) return null;
  var lost = 0.0;
  for (final e in entries) {
    final loss = e.mistake?.loss ?? 0;
    lost += loss.clamp(0, _maxLossCounted) / _maxLossCounted;
  }
  return (100 * (1 - lost / entries.length)).round();
}
