import 'package:flutter/material.dart';

import '../engine/opponent.dart';
import '../engine/piece.dart' as chess;
import 'piece_painter.dart';
import 'progress_store.dart';
import 'settings_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// The gear in a top bar: opens [SettingsScreen].
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.progress});

  final ProgressStore? progress;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SettingsScreen(progress: progress)),
        ),
      );
}

/// Appearance, play and practice preferences, and a way to reset progress.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.progress});

  /// Cleared by "Reset progress"; the button is hidden when null.
  final ProgressStore? progress;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmReset = false;
  bool _done = false;

  Widget _group(List<Widget> rows) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: scheme.outline),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _segmented<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final v in values) ButtonSegment(value: v, label: Text(label(v))),
              ],
              selected: {selected},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(String title, String? note, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: note == null ? null : Text(note),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final theme = Theme.of(context);
    final progress = widget.progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SectionLabel('Appearance'),
            const _Preview(),
            const SizedBox(height: 12),
            _group([
              _segmented<ThemeMode>(
                title: 'Theme',
                values: ThemeMode.values,
                selected: settings.themeMode,
                label: (m) => switch (m) {
                  ThemeMode.system => 'System',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                },
                onChanged: settings.setThemeMode,
              ),
              _segmented<BoardPalette>(
                title: 'Board colors',
                values: BoardPalette.values,
                selected: settings.palette,
                label: (p) => p.label,
                onChanged: settings.setPalette,
              ),
              _segmented<PieceStyle>(
                title: 'Pieces',
                values: PieceStyle.values,
                selected: settings.pieces,
                label: (p) => p.label,
                onChanged: settings.setPieces,
              ),
            ]),
            const SectionLabel('Play'),
            _group([
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Default opponent', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Used when you start a new game.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, box) => DropdownMenu<Level>(
                        width: box.maxWidth,
                        initialSelection: settings.defaultLevel,
                        requestFocusOnTap: false,
                        dropdownMenuEntries: [
                          for (final l in Level.values) DropdownMenuEntry(value: l, label: l.title),
                        ],
                        onSelected: (l) {
                          if (l != null) settings.setDefaultLevel(l);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _segmented<SideChoice>(
                title: 'Play as',
                values: SideChoice.values,
                selected: settings.defaultSide,
                label: (s) => s.label,
                onChanged: settings.setDefaultSide,
              ),
              _switch('Coach after each move', 'Says why your move was good or bad, and why the engine replied.',
                  settings.coach, settings.setCoach),
              _switch('Show legal moves', 'Dots on the squares a selected piece can go to.',
                  settings.showLegalMoves, settings.setShowLegalMoves),
              _switch('Show coordinates', null, settings.showCoordinates, settings.setShowCoordinates),
              _switch('Allow take-backs', 'A game with a take-back is not rated.', settings.allowTakeBacks,
                  settings.setAllowTakeBacks),
            ]),
            const SectionLabel('Practice'),
            _group([
              _switch('Hints one step at a time', 'Where to look, then the idea, then the move.',
                  settings.stepHints, settings.setStepHints),
            ]),
            if (progress != null) ...[
              const SectionLabel('Your data'),
              _group([
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: context.coach.badBg,
                            foregroundColor: context.coach.bad,
                          ),
                          onPressed: () async {
                            if (!_confirmReset) {
                              setState(() => _confirmReset = true);
                              return;
                            }
                            await progress.reset();
                            if (!mounted) return;
                            setState(() {
                              _confirmReset = false;
                              _done = true;
                            });
                          },
                          child: Text(_confirmReset ? 'Tap again to confirm' : 'Reset progress'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _done
                            ? 'Progress cleared.'
                            : _confirmReset
                                ? 'This cannot be undone. Tap the button again to clear it, or leave this screen to cancel.'
                                : 'Clears solved puzzles, weak spots, your rating and the daily streak. Settings stay.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
            const SectionLabel('About'),
            _group([
              ListTile(
                title: const Text('Chess Technique Teacher'),
                subtitle: const Text(
                  'Opponent ratings are targets for how each level is tuned, not measured Elo. '
                  'Endgame claims are checked against exact calculation and lesson positions against the engine.',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Four squares with pieces in the current board colors and piece style.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final colors = context.board.withPalette(settings.palette, Theme.of(context).brightness);
    final flat = settings.pieces == PieceStyle.flat;
    final cells = [
      (colors.light, chess.makePiece(chess.knight, chess.black)),
      (colors.dark, chess.makePiece(chess.queen, chess.white)),
      (colors.light, chess.makePiece(chess.king, chess.white)),
      (colors.dark, chess.makePiece(chess.pawn, chess.black)),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final (color, piece) in cells)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: color,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CustomPaint(painter: PiecePainter(piece, flat: flat)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
