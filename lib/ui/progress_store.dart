import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which puzzles are solved. Storage failures are ignored: the
/// app still works, it just forgets between runs.
class ProgressStore extends ChangeNotifier {
  static const String _key = 'solved_puzzles';

  final Set<String> _solved = {};

  Set<String> get solved => Set.unmodifiable(_solved);

  bool isSolved(String id) => _solved.contains(id);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _solved
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const <String>[]);
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

  Future<void> reset() async {
    _solved.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // No storage available.
    }
  }
}
