import 'package:flutter/material.dart';

import 'settings_store.dart';

/// Colours of the board and its overlays; one set per brightness.
@immutable
class BoardColors extends ThemeExtension<BoardColors> {
  const BoardColors({
    required this.light,
    required this.dark,
    required this.pattern,
    required this.lastMove,
    required this.selected,
    required this.best,
    required this.played,
  });

  final Color light;
  final Color dark;

  /// Squares that make up the idea being explained.
  final Color pattern;
  final Color lastMove;
  final Color selected;

  /// Arrow colours: the move the coach likes, and the one you played.
  final Color best;
  final Color played;

  static const lightSet = BoardColors(
    light: Color(0xFFE9E5D6),
    dark: Color(0xFF5E7F8E),
    pattern: Color(0x8CE8A317),
    lastMove: Color(0x52E8A317),
    selected: Color(0x99E8A317),
    best: Color(0xE61F7A4D),
    played: Color(0xE6B8412F),
  );

  static const darkSet = BoardColors(
    light: Color(0xFFBDBAA9),
    dark: Color(0xFF476775),
    pattern: Color(0x8CF0B33A),
    lastMove: Color(0x52F0B33A),
    selected: Color(0x99F0B33A),
    best: Color(0xE65CC38C),
    played: Color(0xE6EE8A78),
  );

  /// These colours with the square colours of [palette]; slate is the theme's own.
  BoardColors withPalette(BoardPalette palette, Brightness brightness) {
    if (palette == BoardPalette.slate) return this;
    final dark = brightness == Brightness.dark;
    final (l, d) = switch (palette) {
      BoardPalette.green => dark
          ? (const Color(0xFFB9BDA0), const Color(0xFF5A7545))
          : (const Color(0xFFEEEED2), const Color(0xFF769656)),
      _ => dark
          ? (const Color(0xFFC9B48F), const Color(0xFF8E6B4D))
          : (const Color(0xFFF0D9B5), const Color(0xFFB58863)),
    };
    return BoardColors(
      light: l,
      dark: d,
      pattern: pattern,
      lastMove: lastMove,
      selected: selected,
      best: best,
      played: played,
    );
  }

  @override
  BoardColors copyWith() => this;

  @override
  BoardColors lerp(BoardColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Semantic colours beyond Material's scheme: right, wrong, and the single
/// amber accent that means "look here".
@immutable
class CoachColors extends ThemeExtension<CoachColors> {
  const CoachColors({
    required this.good,
    required this.goodBg,
    required this.bad,
    required this.badBg,
  });

  final Color good;
  final Color goodBg;
  final Color bad;
  final Color badBg;

  static const lightSet = CoachColors(
    good: Color(0xFF1F7A4D),
    goodBg: Color(0xFFDDF0E5),
    bad: Color(0xFFB8412F),
    badBg: Color(0xFFF8E2DD),
  );

  static const darkSet = CoachColors(
    good: Color(0xFF5CC38C),
    goodBg: Color(0xFF173226),
    bad: Color(0xFFEE8A78),
    badBg: Color(0xFF3A1D18),
  );

  @override
  CoachColors copyWith() => this;

  @override
  CoachColors lerp(CoachColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension ChessTheme on BuildContext {
  BoardColors get board => Theme.of(this).extension<BoardColors>()!;
  CoachColors get coach => Theme.of(this).extension<CoachColors>()!;
}

const String monoFamily = 'monospace';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFFF0B33A),
          onPrimary: Color(0xFF1A1304),
          secondary: Color(0xFF9DB0AC),
          surface: Color(0xFF152120),
          onSurface: Color(0xFFE8EFED),
          onSurfaceVariant: Color(0xFF9DB0AC),
          surfaceContainerHighest: Color(0xFF1D2D2B),
          surfaceContainerHigh: Color(0xFF1D2D2B),
          outline: Color(0xFF2A3E3B),
          outlineVariant: Color(0xFF2A3E3B),
          error: Color(0xFFEE8A78),
        )
      : const ColorScheme.light(
          primary: Color(0xFFE8A317),
          onPrimary: Color(0xFF1A1304),
          secondary: Color(0xFF4A5B58),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF14211F),
          onSurfaceVariant: Color(0xFF4A5B58),
          surfaceContainerHighest: Color(0xFFE1E7E6),
          surfaceContainerHigh: Color(0xFFE1E7E6),
          outline: Color(0xFFCBD5D3),
          outlineVariant: Color(0xFFCBD5D3),
          error: Color(0xFFB8412F),
        );
  final page = dark ? const Color(0xFF0C1413) : const Color(0xFFECEFEE);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
  );

  TextStyle display(TextStyle? s, double size) => (s ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.15,
      );
  final text = base.textTheme.copyWith(
    headlineSmall: display(base.textTheme.headlineSmall, 24),
    titleLarge: display(base.textTheme.titleLarge, 22),
    titleMedium: display(base.textTheme.titleMedium, 17).copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const minButton = Size(48, 48);

  return base.copyWith(
    textTheme: text,
    extensions: [
      dark ? BoardColors.darkSet : BoardColors.lightSet,
      dark ? CoachColors.darkSet : CoachColors.lightSet,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: page,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: minButton,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: minButton,
        shape: shape,
        side: BorderSide(color: scheme.outline, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      // A selected chip (a Learn filter, a move in a list) is dark with light text.
      selectedColor: scheme.onSurface,
      secondaryLabelStyle: TextStyle(
        color: scheme.surface,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      checkmarkColor: scheme.surface,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: scheme.surface,
        selectedBackgroundColor: scheme.onSurface,
        selectedForegroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        minimumSize: minButton,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.surfaceContainerHighest,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: scheme.onSurface)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (dark ? CoachColors.darkSet.good : CoachColors.lightSet.good)
            : scheme.outline,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
  );
}
