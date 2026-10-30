/// Spaced repetition for puzzles you got wrong: a missed puzzle comes back
/// tomorrow, and each clean solve pushes the next review further out until it
/// is learned.
const List<int> srsIntervals = [1, 3, 7, 14, 30];

class SrsCard {
  const SrsCard({required this.box, required this.due});

  /// 0 = just missed; higher = known for longer.
  final int box;

  /// Day number (see `dayNumber`) on which it is due.
  final int due;

  String encode(String id) => '$id:$box:$due';

  static (String, SrsCard)? decode(String text) {
    final p = text.split(':');
    if (p.length < 3) return null;
    final box = int.tryParse(p[p.length - 2]);
    final due = int.tryParse(p.last);
    if (box == null || due == null || box < 0 || box >= srsIntervals.length) return null;
    return (p.sublist(0, p.length - 2).join(':'), SrsCard(box: box, due: due));
  }
}

/// The card after a try on [today]. A miss starts over (due tomorrow); a clean
/// solve moves up a box. [card] is null for a puzzle not being tracked, and a
/// clean solve of one leaves it untracked. The result is null once the puzzle
/// is learned (a clean solve in the last box) or was never in trouble.
SrsCard? afterReview(SrsCard? card, {required bool correct, required int today}) {
  if (!correct) return SrsCard(box: 0, due: today + srsIntervals.first);
  if (card == null) return null;
  final next = card.box + 1;
  if (next >= srsIntervals.length) return null;
  return SrsCard(box: next, due: today + srsIntervals[next]);
}

/// Ids due on or before [today], most overdue first.
List<String> dueIds(Map<String, SrsCard> cards, int today) {
  final due = [
    for (final e in cards.entries)
      if (e.value.due <= today) e,
  ]..sort((a, b) {
      final c = a.value.due.compareTo(b.value.due);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in due) e.key];
}
