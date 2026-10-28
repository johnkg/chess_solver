import 'package:chess_solver/engine/daily.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day numbers follow the calendar date', () {
    expect(dayNumber(DateTime(1970, 1, 1)), 0);
    expect(dayNumber(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(dayNumber(DateTime(2026, 10, 28)), dayNumber(DateTime(2026, 10, 28, 6)) );
    expect(dateOfDay(dayNumber(DateTime(2026, 10, 28))), DateTime.utc(2026, 10, 28));
  });

  test('same day, same puzzle', () {
    expect(dailyPuzzle(puzzleLibrary, 20000).id, dailyPuzzle(puzzleLibrary, 20000).id);
  });

  test('a full cycle uses every puzzle once, then the next cycle reshuffles', () {
    final n = puzzleLibrary.length;
    final start = 20000 - 20000 % n; // first day of a cycle
    final ids = [for (var d = 0; d < n; d++) dailyPuzzle(puzzleLibrary, start + d).id];
    expect(ids.toSet().length, n);
    final next = [for (var d = 0; d < n; d++) dailyPuzzle(puzzleLibrary, start + n + d).id];
    expect(next.toSet().length, n);
    expect(next, isNot(ids));
  });

  test('streak counts back from today, or from yesterday while today is open', () {
    expect(dailyStreak({}, 10), 0);
    expect(dailyStreak({10}, 10), 1);
    expect(dailyStreak({7, 8, 9, 10}, 10), 4);
    expect(dailyStreak({7, 8, 9}, 10), 3); // today not done yet: still alive
    expect(dailyStreak({7, 8}, 10), 0); // missed yesterday: broken
    expect(dailyStreak({5, 6, 8, 9, 10}, 10), 3);
  });

  test('longest streak', () {
    expect(longestStreak({}), 0);
    expect(longestStreak({3}), 1);
    expect(longestStreak({1, 2, 3, 7, 8, 20}), 3);
  });
}
