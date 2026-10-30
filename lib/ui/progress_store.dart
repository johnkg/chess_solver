import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/rating.dart';
import '../engine/srs.dart';

/// Remembers which puzzles are solved. Storage failures are ignored: the
/// app still works, it just forgets between runs.
class ProgressStore extends ChangeNotifier {
  /// Puzzle ids were renumbered when the library grew, so earlier saved marks
  /// (key 'solved_puzzles') are not read any more.
  static const String _key = 'solved_puzzles_v6';

  static const String _missKey = 'missed_ideas';
  static const String _gamesKey = 'rated_games';
  static const String _dailyKey = 'daily_days';
  static const String _srsKey = 'srs_cards';
  static const String _rushKey = 'rush_best';
  static const String _savedKey = 'saved_games';

  /// How many finished games are kept for later review.
  static const int savedGameLimit = 20;

  final Set<String> _solved = {};
  final Map<String, int> _missed = {};
  final List<GameRecord> _games = [];
  final Set<int> _daily = {};
  final Map<String, SrsCard> _srs = {};
  final List<String> _saved = [];
  int _rushBest = 0;

  /// Puzzles being re-reviewed (missed before), by id.
  Map<String, SrsCard> get srsCards => Map.unmodifiable(_srs);

  /// Puzzles that graduated from review are not tracked here; this counts them.
  int get puzzlesLearned => _learned;
  int _learned = 0;

  /// Puzzle ids due for review on [today].
  List<String> dueForReview(int today) => dueIds(_srs, today);

  /// A puzzle was attempted: [correct] means solved with no miss and no hint.
  Future<void> recordReview(String id, {required bool correct, required int today}) async {
    final before = _srs[id];
    final after = afterReview(before, correct: correct, today: today);
    if (after == null) {
      if (_srs.remove(id) == null) return;
      _learned++;
    } else {
      _srs[id] = after;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_srsKey, [for (final e in _srs.entries) e.value.encode(e.key)]);
      await prefs.setInt('$_srsKey.learned', _learned);
    } catch (_) {
      // No storage available.
    }
  }

  /// Best Puzzle Rush score.
  int get rushBest => _rushBest;

  /// Keeps [score] if it beats the best; returns whether it did.
  Future<bool> recordRush(int score) async {
    if (score <= _rushBest) return false;
    _rushBest = score;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_rushKey, score);
    } catch (_) {
      // No storage available.
    }
    return true;
  }

  /// PGN texts of the last finished games, newest first.
  List<String> get savedGames => List.unmodifiable(_saved);

  /// Keeps a finished game's PGN for review later.
  Future<void> saveGame(String pgn) async {
    _saved
      ..remove(pgn)
      ..insert(0, pgn);
    if (_saved.length > savedGameLimit) _saved.removeRange(savedGameLimit, _saved.length);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedKey, _saved);
    } catch (_) {
      // No storage available.
    }
  }

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
      _srs
        ..clear()
        ..addEntries([
          for (final line in prefs.getStringList(_srsKey) ?? const <String>[])
            if (SrsCard.decode(line) case (final id, final card)) MapEntry(id, card),
        ]);
      _learned = prefs.getInt('$_srsKey.learned') ?? 0;
      _rushBest = prefs.getInt(_rushKey) ?? 0;
      _saved
        ..clear()
        ..addAll(prefs.getStringList(_savedKey) ?? const <String>[]);
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
    _srs.clear();
    _saved.clear();
    _learned = 0;
    _rushBest = 0;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_missKey);
      await prefs.remove(_gamesKey);
      await prefs.remove(_dailyKey);
      await prefs.remove(_srsKey);
      await prefs.remove('$_srsKey.learned');
      await prefs.remove(_rushKey);
      await prefs.remove(_savedKey);
    } catch (_) {
      // No storage available.
    }
  }
}
