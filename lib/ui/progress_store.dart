import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which puzzles are solved. Storage failures are ignored: the
/// app still works, it just forgets between runs.
class ProgressStore extends ChangeNotifier {
  static const String _key = 'solved_puzzles';

  static const String _missKey = 'missed_ideas';

  final Set<String> _solved = {};
  final Map<String, int> _missed = {};

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
      notifyListeners();
    } catch (_) {
      // No storage available.
    }
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
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_missKey);
    } catch (_) {
      // No storage available.
    }
  }
}
