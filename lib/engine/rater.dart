import 'explainer.dart';
import 'insight.dart';
import 'mistakes.dart';
import 'move.dart';
import 'position.dart';
import 'san.dart';
import 'search.dart';

/// How far a solution must beat the runner-up (centipawns) for a material
/// puzzle to count as having one clear answer.
const int uniqueMargin = 200;

/// The named idea must account for the advantage to within this much
/// (centipawns), or the position is not a clean puzzle.
const int explainSlack = 100;

/// Default depth for the forced-mate search.
const int defaultMaxMate = 3;

/// Mate puzzles may have this many equal first moves (ladder mates often
/// have a mirror-image twin).
const int maxSolutions = 4;

/// Difficulty tier of each idea a puzzle can be built on (1 = easiest).
const Map<Idea, int> ideaTier = {
  Idea.hangingPiece: 1,
  Idea.checkmate: 1,
  Idea.backRankMate: 2,
  Idea.fork: 2,
  Idea.skewer: 2,
  Idea.removingDefender: 3,
  Idea.discoveredAttack: 3,
  Idea.doubleCheck: 3,
  Idea.smotheredMate: 3,
};

/// Tier of a forced mate in 2 and 3.
const Map<int, int> mateTier = {2: 4, 3: 5};

/// Inside one tier the more specific idea wins.
const List<Idea> ideaPriority = [
  Idea.smotheredMate,
  Idea.backRankMate,
  Idea.doubleCheck,
  Idea.discoveredAttack,
  Idea.removingDefender,
  Idea.skewer,
  Idea.fork,
  Idea.checkmate,
  Idea.hangingPiece,
];

/// How a position rates as a puzzle.
class PuzzleRating {
  /// Winning first moves in UCI, sorted. One for material puzzles.
  final List<String> solutions;

  /// The first solution in standard algebraic notation.
  final String san;

  /// The idea the solution needs; null for a mate in 2 or 3.
  final Idea? idea;

  /// Difficulty tier, 1 (easiest) to 5.
  final int tier;

  /// 1 to 3 for a forced mate, 0 for a material puzzle.
  final int mateIn;

  /// Plain-words reason the solution works.
  final String text;

  const PuzzleRating({
    required this.solutions,
    required this.san,
    required this.idea,
    required this.tier,
    required this.mateIn,
    required this.text,
  });

  @override
  String toString() =>
      'PuzzleRating($solutions, ${idea?.name}, tier $tier, mate $mateIn)';
}

/// Does [m] force mate within [n] of the mover's own moves?
bool isMateMove(Position pos, Move m, int n) {
  final next = pos.makeMove(m);
  final replies = next.legalMoves();
  if (replies.isEmpty) return next.inCheck;
  if (n == 1) return false;
  return replies.every((r) => mateIn(next.makeMove(r), n - 1) != null);
}

/// The mate patterns, most specific first.
const List<Idea> mateIdeas = [
  Idea.smotheredMate,
  Idea.backRankMate,
  Idea.checkmate,
];

/// The idea that explains the solution.
///
/// With [mate] (a mate in 1): the most specific mate pattern. Otherwise the
/// idea that wins the most material; ties go to the harder tier, then to the
/// more specific idea. So Qxa8 winning a free rook is a free piece, not a
/// "fork" of two pawns it also happens to attack.
Insight? pickIdea(List<Insight> insights, {bool mate = false}) {
  Insight? best;
  if (mate) {
    for (final i in insights) {
      if (!mateIdeas.contains(i.idea)) continue;
      if (best == null ||
          mateIdeas.indexOf(i.idea) < mateIdeas.indexOf(best.idea)) {
        best = i;
      }
    }
    return best;
  }
  for (final i in insights) {
    if (!ideaTier.containsKey(i.idea) || mateIdeas.contains(i.idea)) continue;
    if (best == null) {
      best = i;
      continue;
    }
    final bestTier = ideaTier[best.idea]!;
    final tier = ideaTier[i.idea]!;
    final better = i.gain != best.gain
        ? i.gain > best.gain
        : tier != bestTier
            ? tier > bestTier
            : ideaPriority.indexOf(i.idea) < ideaPriority.indexOf(best.idea);
    if (better) best = i;
  }
  return best;
}

/// Null if [pos] is not a clean puzzle, otherwise its rating.
///
/// A mate puzzle has one to [maxSolutions] first moves that force the
/// shortest mate (up to [maxMate] moves). A material puzzle has one move
/// that beats every other by [uniqueMargin] and whose search-verified
/// insights name an idea that explains the advantage to within
/// [explainSlack]. [maxMate] bounds the forced-mate search;
/// a deeper mate is then rated as a material puzzle, if it is one.
PuzzleRating? ratePuzzle(
  Position pos, {
  int depth = 3,
  int maxMate = defaultMaxMate,
}) {
  final legal = pos.legalMoves();
  if (legal.isEmpty) return null;

  final mate = findMate(pos, maxMate);
  if (mate != null) {
    final n = mate.moves;
    final sols = [
      for (final m in legal)
        if (isMateMove(pos, m, n)) (m.uci, m),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (sols.isEmpty || sols.length > maxSolutions) return null;

    final names = [for (final s in sols) s.$1];
    final first = sols.first.$2;
    final firstSan = san(pos, first);
    if (n == 1) {
      final ins = pickIdea(explainVerified(pos, first), mate: true);
      final idea = ins?.idea ?? Idea.checkmate;
      return PuzzleRating(
        solutions: names,
        san: firstSan,
        idea: idea,
        tier: ideaTier[idea]!,
        mateIn: 1,
        text: ins?.text ?? 'Checkmate.',
      );
    }
    return PuzzleRating(
      solutions: names,
      san: firstSan,
      idea: null,
      tier: mateTier[n]!,
      mateIn: n,
      text: '$firstSan forces checkmate in $n: every reply still runs into '
          'mate.',
    );
  }

  final scored = scoreMoves(pos, depth)
    ..sort((a, b) => b.$2.compareTo(a.$2));
  if (scored.length < 2) return null;
  final gap = scored[0].$2 - scored[1].$2;
  if (gap < uniqueMargin) return null;
  final best = scored[0].$1;
  final ins = pickIdea(explainVerified(pos, best));
  // No idea, or the idea explains only a fraction of why the move wins.
  if (ins == null || ins.gain <= 0 || ins.gain + explainSlack < gap) {
    return null;
  }
  return PuzzleRating(
    solutions: [best.uci],
    san: san(pos, best),
    idea: ins.idea,
    tier: ideaTier[ins.idea]!,
    mateIn: 0,
    text: ins.text,
  );
}
