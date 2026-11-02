import 'dart:math';

import 'book.dart';
import 'engine.dart';
import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'search.dart';

/// The knobs that make the computer opponent weaker or stronger. A [Level]
/// is a named set of these; tools can try other sets without a new level.
class LevelSettings {
  const LevelSettings({
    required this.depth,
    required this.millis,
    required this.temperature,
    required this.margin,
    required this.bookPlies,
    this.mateDepth = 0,
  });

  /// Deepest search in plies.
  final int depth;

  /// Thinking time per move, milliseconds.
  final int millis;

  /// Among moves close to the best, the chance of choosing one falls off by
  /// a factor of e for every [temperature] centipawns it is worse. Low
  /// temperature = nearly always the best move.
  final int temperature;

  /// Moves further than this from the best are never played.
  final int margin;

  /// The opening book is used for this many half-moves.
  final int bookPlies;

  /// Plain forced-mate search before thinking (the weakest levels only see
  /// mate in 1). Zero means the normal search finds mates by itself.
  final int mateDepth;
}

/// How strong the computer opponent plays. The ratings are targets for how
/// each level is tuned (search depth, thinking time, how often it plays a
/// near-best move instead of the best one); they are not measured Elo.
enum Level {
  beginner('Beginner', 600,
      LevelSettings(depth: 1, millis: 150, temperature: 150, margin: 350, bookPlies: 2, mateDepth: 1)),
  novice('Novice', 800,
      LevelSettings(depth: 1, millis: 200, temperature: 71, margin: 213, bookPlies: 4, mateDepth: 1)),
  casual('Casual', 1000,
      LevelSettings(depth: 1, millis: 250, temperature: 14, margin: 42, bookPlies: 6, mateDepth: 1)),
  intermediate('Intermediate', 1200,
      LevelSettings(depth: 2, millis: 350, temperature: 26, margin: 78, bookPlies: 8, mateDepth: 2)),
  club('Club', 1400,
      LevelSettings(depth: 3, millis: 500, temperature: 35, margin: 105, bookPlies: 10, mateDepth: 2)),
  advanced('Advanced', 1600,
      LevelSettings(depth: 3, millis: 700, temperature: 15, margin: 45, bookPlies: 12, mateDepth: 2)),
  expert('Expert', 1800,
      LevelSettings(depth: 4, millis: 1000, temperature: 14, margin: 42, bookPlies: 14)),
  candidateMaster('Candidate Master', 2000,
      LevelSettings(depth: 5, millis: 1500, temperature: 7, margin: 25, bookPlies: 16)),
  master('Master', 2200,
      LevelSettings(depth: 6, millis: 2500, temperature: 5, margin: 25, bookPlies: 20)),
  internationalMaster('International Master', 2400,
      LevelSettings(depth: 8, millis: 3500, temperature: 5, margin: 32, bookPlies: 22)),
  grandmaster('Grandmaster', 2500,
      LevelSettings(depth: 10, millis: 5000, temperature: 3, margin: 25, bookPlies: 24));

  const Level(this.label, this.elo, this.settings);

  final String label;

  /// Target playing strength (see the note above).
  final int elo;

  final LevelSettings settings;

  int get depth => settings.depth;
  int get millis => settings.millis;
  int get temperature => settings.temperature;
  int get mateDepth => settings.mateDepth;

  String get title => '$label · about $elo';
}

/// The opponent's reply in [pos], or null if there is no legal move.
///
/// It plays an opening line from its book (a different one each game), and
/// afterwards searches for the best moves. Rather than always playing the
/// single best move it picks among the near-best ones, weighted by how good
/// they are, so games differ but every move still has a reason. A forced
/// mate is always played when found. [maxMillis] overrides the level's
/// thinking time (tests use it).
Move? chooseMove(
  Position pos,
  Level level, [
  Random? random,
  int? maxMillis,
  List<String> history = const [],
]) =>
    chooseMoveWith(pos, level.settings, random, maxMillis, history);

/// [chooseMove] for any [LevelSettings], not only a named [Level].
Move? chooseMoveWith(
  Position pos,
  LevelSettings settings, [
  Random? random,
  int? maxMillis,
  List<String> history = const [],
]) {
  final rng = random ?? Random();
  final quick = _quickMove(pos, settings, rng);
  if (quick != null) return quick.$1;
  final result = Searcher().search(
    pos,
    maxDepth: settings.depth,
    millis: maxMillis ?? settings.millis,
    margin: settings.margin,
    history: history,
  );
  return result == null ? null : _pick(result, settings, rng);
}

/// [chooseMove] that keeps the UI alive while it thinks. Set
/// `searcher.cancelled` to abandon the search; the result is then null.
Future<Move?> chooseMoveAsync(
  Position pos,
  Level level, {
  Random? random,
  int? maxMillis,
  Searcher? searcher,
  List<String> history = const [],
}) async {
  final rng = random ?? Random();
  final settings = level.settings;
  final quick = _quickMove(pos, settings, rng);
  if (quick != null) return quick.$1;
  final result = await (searcher ?? Searcher()).searchAsync(
    pos,
    maxDepth: settings.depth,
    millis: maxMillis ?? settings.millis,
    margin: settings.margin,
    history: history,
  );
  return result == null ? null : _pick(result, settings, rng);
}

/// A move that needs no search: the only legal move, a short mate for the
/// weak levels, or the book. The record wraps the move so that "none" and
/// "no answer yet" differ; null means search.
(Move?,)? _quickMove(Position pos, LevelSettings settings, Random rng) {
  final legal = pos.legalMoves();
  if (legal.isEmpty) return (null,);
  if (legal.length == 1) return (legal.first,);
  if (settings.mateDepth > 0) {
    final mate = findMate(pos, settings.mateDepth);
    if (mate != null) return (mate.move,);
  }
  final booked = bookMove(pos, settings.bookPlies, rng);
  return booked == null ? null : (booked,);
}

Move _pick(SearchResult result, LevelSettings settings, Random rng) {
  final best = result.best.$2;
  if (isMateScore(best)) return result.best.$1;
  final weights = [
    for (final e in result.moves) exp(-(best - e.$2) / settings.temperature),
  ];
  var pick = rng.nextDouble() * weights.reduce((a, b) => a + b);
  for (var i = 0; i < weights.length; i++) {
    pick -= weights[i];
    if (pick <= 0) return result.moves[i].$1;
  }
  return result.best.$1;
}

/// Why the game is drawn (other than stalemate), or null. [seen] holds the
/// [Position.repetitionKey] of every earlier position in the game; a third
/// occurrence of [pos] is a draw.
String? drawReason(Position pos, {List<String> seen = const []}) {
  if (pos.isFiftyMoveDraw) return 'Draw by the fifty-move rule';
  if (pos.canHaveRepeated) {
    final key = pos.repetitionKey;
    if (seen.where((k) => k == key).length >= 2) return 'Draw by threefold repetition';
  }
  var minors = 0;
  for (final p in pos.squares) {
    if (p == empty) continue;
    switch (pieceType(p)) {
      case king:
        break;
      case knight || bishop:
        minors++;
      default:
        return null;
    }
  }
  return minors <= 1 ? 'Draw: not enough pieces to checkmate' : null;
}
