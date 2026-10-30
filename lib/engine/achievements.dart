/// What the player has done so far, from the saved progress.
class ProgressStats {
  const ProgressStats({
    this.puzzlesSolved = 0,
    this.matesSolved = 0,
    this.bestDailyStreak = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.peakRating = 1000,
    this.linesLearned = 0,
    this.rushBest = 0,
    this.puzzlesLearned = 0,
  });

  final int puzzlesSolved;
  final int matesSolved;
  final int bestDailyStreak;
  final int gamesPlayed;
  final int wins;
  final int peakRating;
  final int linesLearned;
  final int rushBest;

  /// Missed puzzles that graduated from spaced repetition.
  final int puzzlesLearned;
}

/// A goal with a progress bar; earned when [current] reaches [target].
class Achievement {
  const Achievement(this.id, this.title, this.description, this.current, this.target);

  final String id;
  final String title;
  final String description;
  final int current;
  final int target;

  bool get earned => current >= target;

  /// 0..1 for the progress bar.
  double get fraction => target == 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// Every badge with the player's progress towards it.
List<Achievement> badgesFor(ProgressStats s) => [
      Achievement('first-puzzle', 'First steps', 'Solve a puzzle.', s.puzzlesSolved, 1),
      Achievement('puzzles-25', 'Apprentice', 'Solve 25 puzzles.', s.puzzlesSolved, 25),
      Achievement('puzzles-100', 'Tactician', 'Solve 100 puzzles.', s.puzzlesSolved, 100),
      Achievement('mates-15', 'Mating net', 'Solve 15 checkmate puzzles.', s.matesSolved, 15),
      Achievement('streak-3', 'On a roll', 'Solve the daily puzzle 3 days in a row.', s.bestDailyStreak, 3),
      Achievement('streak-7', 'Regular', 'Solve the daily puzzle 7 days in a row.', s.bestDailyStreak, 7),
      Achievement('first-win', 'First win', 'Beat the engine in a rated game.', s.wins, 1),
      Achievement('games-10', 'Seasoned', 'Play 10 rated games.', s.gamesPlayed, 10),
      Achievement('rating-1200', 'Rated 1200', 'Reach a rating of 1200.', s.peakRating, 1200),
      Achievement('rating-1400', 'Rated 1400', 'Reach a rating of 1400.', s.peakRating, 1400),
      Achievement('lines-5', 'Repertoire', 'Learn 5 opening lines or famous games.', s.linesLearned, 5),
      Achievement('rush-10', 'Quick eye', 'Score 10 in Puzzle Rush.', s.rushBest, 10),
      Achievement('rush-25', 'Lightning', 'Score 25 in Puzzle Rush.', s.rushBest, 25),
      Achievement('learned-5', 'No repeats', 'Master 5 puzzles you missed before.', s.puzzlesLearned, 5),
    ];
