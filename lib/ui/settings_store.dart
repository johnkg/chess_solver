import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/opponent.dart';
import '../engine/piece.dart' as chess;

/// Colours of the board squares.
enum BoardPalette {
  slate('Slate'),
  green('Green'),
  wood('Wood');

  const BoardPalette(this.label);

  final String label;
}

/// How the pieces are drawn.
enum PieceStyle {
  solid3d('3D'),
  flat('Flat');

  const PieceStyle(this.label);

  final String label;
}

/// Which side you play in a new game.
enum SideChoice {
  white('White'),
  black('Black'),
  random('Random');

  const SideChoice(this.label);

  final String label;

  /// The colour to play, picking at random for [random].
  int resolve(Random rng) => switch (this) {
        SideChoice.white => chess.white,
        SideChoice.black => chess.black,
        SideChoice.random => rng.nextBool() ? chess.white : chess.black,
      };
}

/// Preferences chosen on the Settings screen. Storage failures are ignored:
/// the app still works, it just forgets between runs.
class SettingsStore extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  BoardPalette palette = BoardPalette.slate;
  PieceStyle pieces = PieceStyle.solid3d;
  Level defaultLevel = Level.casual;
  SideChoice defaultSide = SideChoice.white;

  /// Says why your move was good or bad, and why the engine replied.
  bool coach = true;

  /// Dots on the squares a selected piece can go to.
  bool showLegalMoves = true;
  bool showCoordinates = true;
  bool allowTakeBacks = true;

  /// Hints go from "where to look" to "the move" one step at a time.
  bool stepHints = true;

  static const String _prefix = 'settings_';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      T pick<T>(List<T> values, String key, T fallback) {
        final name = prefs.getString('$_prefix$key');
        for (final v in values) {
          if ((v as Enum).name == name) return v;
        }
        return fallback;
      }

      themeMode = pick(ThemeMode.values, 'theme', themeMode);
      palette = pick(BoardPalette.values, 'palette', palette);
      pieces = pick(PieceStyle.values, 'pieces', pieces);
      defaultLevel = pick(Level.values, 'level', defaultLevel);
      defaultSide = pick(SideChoice.values, 'side', defaultSide);
      coach = prefs.getBool('${_prefix}coach') ?? coach;
      showLegalMoves = prefs.getBool('${_prefix}legal') ?? showLegalMoves;
      showCoordinates = prefs.getBool('${_prefix}coords') ?? showCoordinates;
      allowTakeBacks = prefs.getBool('${_prefix}takebacks') ?? allowTakeBacks;
      stepHints = prefs.getBool('${_prefix}stephints') ?? stepHints;
      notifyListeners();
    } catch (_) {
      // No storage available.
    }
  }

  Future<void> _save(String key, Object value) async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool('$_prefix$key', value);
      } else if (value is Enum) {
        await prefs.setString('$_prefix$key', value.name);
      }
    } catch (_) {
      // No storage available.
    }
  }

  Future<void> setThemeMode(ThemeMode v) {
    themeMode = v;
    return _save('theme', v);
  }

  Future<void> setPalette(BoardPalette v) {
    palette = v;
    return _save('palette', v);
  }

  Future<void> setPieces(PieceStyle v) {
    pieces = v;
    return _save('pieces', v);
  }

  Future<void> setDefaultLevel(Level v) {
    defaultLevel = v;
    return _save('level', v);
  }

  Future<void> setDefaultSide(SideChoice v) {
    defaultSide = v;
    return _save('side', v);
  }

  Future<void> setCoach(bool v) {
    coach = v;
    return _save('coach', v);
  }

  Future<void> setShowLegalMoves(bool v) {
    showLegalMoves = v;
    return _save('legal', v);
  }

  Future<void> setShowCoordinates(bool v) {
    showCoordinates = v;
    return _save('coords', v);
  }

  Future<void> setAllowTakeBacks(bool v) {
    allowTakeBacks = v;
    return _save('takebacks', v);
  }

  Future<void> setStepHints(bool v) {
    stepHints = v;
    return _save('stephints', v);
  }
}

/// Makes the settings available to every screen. Widgets built without a
/// scope (some tests) see the defaults.
class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({super.key, required SettingsStore settings, required super.child})
      : super(notifier: settings);

  static final SettingsStore _defaults = SettingsStore();

  static SettingsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier ?? _defaults;
}
