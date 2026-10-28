import 'dart:math';

import 'puzzle.dart';

/// Whole days since 1970-01-01 for the calendar date of [t] (the local date,
/// so "today" changes at the player's midnight).
int dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

/// The calendar date for a [day] number from [dayNumber].
DateTime dateOfDay(int day) => DateTime.utc(1970, 1, 1).add(Duration(days: day));

/// The puzzle for [day]. Everyone gets the same one on the same day, and
/// no puzzle comes back until the whole library has been used: the days are
/// cut into runs of `library.length`, and each run walks through the library
/// in its own shuffled order.
Puzzle dailyPuzzle(List<Puzzle> library, int day) {
  final n = library.length;
  final cycle = day ~/ n;
  final order = List<int>.generate(n, (i) => i)..shuffle(Random(cycle));
  return library[order[day % n]];
}

/// Length of the run of consecutive solved days that ends [today], or
/// yesterday if today is not solved yet (the streak is still alive).
int dailyStreak(Set<int> solved, int today) {
  var day = solved.contains(today) ? today : today - 1;
  var n = 0;
  while (solved.contains(day)) {
    n++;
    day--;
  }
  return n;
}

/// The longest run of consecutive solved days ever.
int longestStreak(Set<int> solved) {
  var best = 0;
  for (final d in solved) {
    if (solved.contains(d - 1)) continue; // not the start of a run
    var n = 0;
    while (solved.contains(d + n)) {
      n++;
    }
    if (n > best) best = n;
  }
  return best;
}
