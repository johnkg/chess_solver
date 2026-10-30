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
class Badge {
  const Badge(this.id, this.title, this.description, this.current, this.target);

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
List<Badge> badgesFor(ProgressStats s) => [
      Badge('first-puzzle', 'First steps', 'Solve a puzzle.', s.puzzlesSolved, 1),
      Badge('puzzles-25', 'Apprentice', 'Solve 25 puzzles.', s.puzzlesSolved, 25),
      Badge('puzzles-100', 'Tactician', 'Solve 100 puzzles.', s.puzzlesSolved, 100),
      Badge('mates-15', 'Mating net', 'Solve 15 checkmate puzzles.', s.matesSolved, 15),
      Badge('streak-3', 'On a roll', 'Solve the daily puzzle 3 days in a row.', s.bestDailyStreak, 3),
      Badge('streak-7', 'Regular', 'Solve the daily puzzle 7 days in a row.', s.bestDailyStreak, 7),
      Badge('first-win', 'First win', 'Beat the engine in a rated game.', s.wins, 1),
      Badge('games-10', 'Seasoned', 'Play 10 rated games.', s.gamesPlayed, 10),
      Badge('rating-1200', 'Rated 1200', 'Reach a rating of 1200.', s.peakRating, 1200),
      Badge('rating-1400', 'Rated 1400', 'Reach a rating of 1400.', s.peakRating, 1400),
      Badge('lines-5', 'Repertoire', 'Learn 5 opening lines or famous games.', s.linesLearned, 5),
      Badge('rush-10', 'Quick eye', 'Score 10 in Puzzle Rush.', s.rushBest, 10),
      Badge('rush-25', 'Lightning', 'Score 25 in Puzzle Rush.', s.rushBest, 25),
      Badge('learned-5', 'No repeats', 'Master 5 puzzles you missed before.', s.puzzlesLearned, 5),
    ];
