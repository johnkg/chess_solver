import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/rating.dart';

/// Remembers which puzzles are solved. Storage failures are ignored: the
/// app still works, it just forgets between runs.
class ProgressStore extends ChangeNotifier {
  /// Puzzle ids were renumbered when the library grew, so earlier saved marks
  /// (key 'solved_puzzles') are not read any more.
  static const String _key = 'solved_puzzles_v5';

  static const String _missKey = 'missed_ideas';
  static const String _gamesKey = 'rated_games';
  static const String _dailyKey = 'daily_days';

  final Set<String> _solved = {};
  final Map<String, int> _missed = {};
  final List<GameRecord> _games = [];
  final Set<int> _daily = {};

  /// Day numbers (see `dayNumber`) on which the daily puzzle was solved.
  Set<int> get dailyDays => Set.unmodifiable(_daily);

  /// The daily puzzle of [day] was solved.
  Future<void> markDaily(int day) async {
    if (!_daily.add(day)) return;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dailyKey, [for (final d in _daily) '$d']);
    } catch (_) {
      // No storage available.
    }
  }

  /// Rated games against the engine, oldest first.
  List<GameRecord> get games => List.unmodifiable(_games);

  /// Current rating: starts at [startRating], moves with each rated game.
  int get rating => _games.isEmpty ? startRating : _games.last.ratingAfter;

  /// Highest rating reached.
  int get peakRating =>
      _games.fold(startRating, (best, g) => g.ratingAfter > best ? g.ratingAfter : best);

  /// How often each idea (see `weakKey`) was missed, net of later successes.
  Map<String, int> get missed => Map.unmodifiable(_missed);

  Set<String> get solved => Set.unmodifiable(_solved);

  bool isSolved(String id) => _solved.contains(id);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _solved
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const <String>[]);
      _missed.clear();
      for (final line in prefs.getStringList(_missKey) ?? const <String>[]) {
        final i = line.lastIndexOf(':');
        final n = i < 0 ? null : int.tryParse(line.substring(i + 1));
        if (n != null && n > 0) _missed[line.substring(0, i)] = n;
      }
      _games
        ..clear()
        ..addAll([
          for (final line in prefs.getStringList(_gamesKey) ?? const <String>[])
            ?GameRecord.decode(line),
        ]);
      _daily
        ..clear()
        ..addAll([
          for (final d in prefs.getStringList(_dailyKey) ?? const <String>[])
            ?int.tryParse(d),
        ]);
      notifyListeners();
    } catch (_) {
      // No storage available.
    }
  }

  /// Records a finished game against an opponent of [opponentElo] and returns
  /// the new rating. [score] is 1, 0.5 or 0.
  Future<int> recordGame(int opponentElo, double score) async {
    final after = updatedRating(rating, opponentElo, score, games: _games.length);
    _games.add(GameRecord(opponentElo: opponentElo, score: score, ratingAfter: after));
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_gamesKey, [for (final g in _games) g.encode()]);
    } catch (_) {
      // No storage available.
    }
    return after;
  }

  Future<void> markSolved(String id) async {
    if (!_solved.add(id)) return;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _solved.toList());
    } catch (_) {
      // No storage available.
    }
  }

  /// The player missed [key]; it moves up the weak-spot list.
  Future<void> recordMiss(String key) async {
    _missed[key] = (_missed[key] ?? 0) + 1;
    notifyListeners();
    await _saveMissed();
  }

  /// The player found [key] when it mattered; it moves down the list.
  Future<void> relieve(String key) async {
    final n = _missed[key] ?? 0;
    if (n <= 0) return;
    if (n == 1) {
      _missed.remove(key);
    } else {
      _missed[key] = n - 1;
    }
    notifyListeners();
    await _saveMissed();
  }

  Future<void> _saveMissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _missKey,
        [for (final e in _missed.entries) '${e.key}:${e.value}'],
      );
    } catch (_) {
      // No storage available.
    }
  }

  Future<void> reset() async {
    _solved.clear();
    _missed.clear();
    _games.clear();
    _daily.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_missKey);
      await prefs.remove(_gamesKey);
      await prefs.remove(_dailyKey);
    } catch (_) {
      // No storage available.
    }
  }
}
