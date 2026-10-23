import 'move.dart';

/// The named ideas the explainer can recognise. Levels follow PLAN.md.
enum Idea {
  checkmate,
  backRankMate,
  smotheredMate,
  doubleCheck,
  hangingPiece,
  fork,
  discoveredAttack,
  removingDefender,
  pin,
  skewer,
  castling,
  development,
  center,
}

/// A material claim ("wins a piece", "forks two pieces") must be confirmed
/// by search before it is told to the learner; see [Insight.verified].
/// Only insights with a positive [Insight.gain] are checked.
const Set<Idea> materialIdeas = {
  Idea.hangingPiece,
  Idea.fork,
  Idea.skewer,
  Idea.discoveredAttack,
  Idea.removingDefender,
};

/// One reason a move is good: which idea, where on the board, and a plain
/// sentence naming the real pieces and squares.
class Insight {
  final Idea idea;
  final Move move;

  /// Squares for the UI to highlight: the pattern's pieces.
  final List<int> squares;

  /// Material the idea claims to win, in centipawns (0 for ideas that do
  /// not win material directly, such as a pin or development).
  final int gain;

  final String text;

  /// Curriculum level (see PLAN.md).
  final int level;

  /// True when a search confirmed the claimed [gain].
  final bool verified;

  const Insight({
    required this.idea,
    required this.move,
    required this.squares,
    required this.gain,
    required this.text,
    required this.level,
    this.verified = false,
  });

  Insight asVerified() => Insight(
        idea: idea,
        move: move,
        squares: squares,
        gain: gain,
        text: text,
        level: level,
        verified: true,
      );

  @override
  String toString() => '${idea.name}: $text';
}
