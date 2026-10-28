import '../engine/opponent.dart';
import '../engine/insight.dart';
import '../engine/piece.dart';
import '../engine/review.dart';
import '../engine/position.dart';

/// Short name of an idea for buttons and hints.
String ideaLabel(Idea idea) => switch (idea) {
      Idea.checkmate => 'Checkmate',
      Idea.backRankMate => 'Back-rank mate',
      Idea.smotheredMate => 'Smothered mate',
      Idea.doubleCheck => 'Double check',
      Idea.hangingPiece => 'A free piece',
      Idea.fork => 'A fork',
      Idea.discoveredAttack => 'A discovered attack',
      Idea.removingDefender => 'Removing the defender',
      Idea.pin => 'A pin',
      Idea.skewer => 'A skewer',
      Idea.castling => 'Castling',
      Idea.development => 'Development',
      Idea.center => 'Fighting for the center',
    };

/// Section titles for the Learn tab.
String levelTitle(int level) => switch (level) {
      1 => 'Level 1 · How the pieces move',
      2 => 'Level 2 · Finishing the game',
      3 => 'Level 3 · Good habits',
      4 => 'Level 4 · Tactics',
      5 => 'Level 5 · Endgames',
      6 => 'Level 6 · Middlegame plans',
      7 => 'Level 7 · Famous games',
      8 => 'Level 8 · Opening lines',
      _ => 'Level $level',
    };

/// Section titles for the Practice tab.
String tierTitle(int tier) => switch (tier) {
      1 => 'Tier 1 · Win a piece or deliver mate',
      2 => 'Tier 2 · Forks, skewers and back-rank mates',
      3 => 'Tier 3 · Hidden ideas',
      4 => 'Tier 4 · Mate in 2',
      5 => 'Tier 5 · Mate in 3',
      _ => 'Tier $tier',
    };

/// One line about whose turn it is, or how the game ended.
String statusText(Position pos) {
  if (pos.isCheckmate) {
    return '${colorName(1 - pos.turn)} wins by checkmate';
  }
  if (pos.isStalemate) return 'Stalemate: a draw';
  return '${colorName(pos.turn)} to move${pos.inCheck ? ' (in check)' : ''}';
}

/// Name of a weak-spot key (see `weakKey`) for the Practice tab.
String weakLabel(String key) => key == mateKey
    ? 'Forced mates'
    : ideaLabel(Idea.values.byName(key));

/// "Endgame" for a drill's phase key.
String phaseLabel(String phase) => switch (phase) {
      'opening' => 'Opening',
      'middlegame' => 'Middlegame',
      'endgame' => 'Endgame',
      _ => phase,
    };

/// One line on how a computer level plays, from its real settings.
String levelBlurb(Level level) {
  final moves = level.depth == 1 ? '1 move' : '${level.depth} moves';
  final seconds = level.millis < 1000
      ? '${(level.millis / 1000).toStringAsFixed(2)} s'
      : '${(level.millis / 1000).toStringAsFixed(level.millis % 1000 == 0 ? 0 : 1)} s';
  final mate = level.mateDepth > 0
      ? 'Spots mate in ${level.mateDepth}.'
      : 'Finds longer mates on its own.';
  return 'Looks $moves ahead and thinks up to $seconds a move. $mate';
}
