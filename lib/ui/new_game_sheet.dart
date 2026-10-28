import 'package:flutter/material.dart';

import '../engine/clock.dart';
import '../engine/opponent.dart';
import 'labels.dart';
import 'settings_store.dart';
import 'theme.dart';

/// What the New game sheet hands back.
class NewGameChoice {
  const NewGameChoice(this.level, this.side, this.control);

  final Level level;
  final SideChoice side;
  final TimeControl control;
}

/// A bottom sheet: pick the opponent with a slider, your side and a clock,
/// then start. Returns null when dismissed.
Future<NewGameChoice?> showNewGameSheet(
  BuildContext context, {
  required Level level,
  required SideChoice side,
  required TimeControl control,
}) {
  return showModalBottomSheet<NewGameChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NewGameSheet(level: level, side: side, control: control),
  );
}

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.level, required this.side, required this.control});

  final Level level;
  final SideChoice side;
  final TimeControl control;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late Level _level = widget.level;
  late SideChoice _side = widget.side;
  late TimeControl _control = widget.control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New game', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.onSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_level.elo}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.primary,
                      fontFamily: monoFamily,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(_level.label, style: theme.textTheme.titleMedium?.copyWith(color: scheme.surface)),
                  const SizedBox(height: 2),
                  Text(
                    levelBlurb(_level),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.surface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('OPPONENT STRENGTH', style: theme.textTheme.labelMedium),
            Slider(
              value: _level.index.toDouble(),
              min: 0,
              max: (Level.values.length - 1).toDouble(),
              divisions: Level.values.length - 1,
              label: _level.label,
              semanticFormatterCallback: (v) => Level.values[v.round()].title,
              onChanged: (v) => setState(() => _level = Level.values[v.round()]),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in [Level.beginner, Level.club, Level.expert, Level.master, Level.grandmaster])
                  Text('${l.elo}', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 14),
            Text('YOU PLAY', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SideChoice>(
                showSelectedIcon: false,
                segments: [
                  for (final s in SideChoice.values) ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_side},
                onSelectionChanged: (s) => setState(() => _side = s.first),
              ),
            ),
            const SizedBox(height: 14),
            Text('CLOCK', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in TimeControl.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _control == c,
                    onSelected: (_) => setState(() => _control = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, NewGameChoice(_level, _side, _control)),
                child: const Text('Start game'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ratings are targets for how each level is tuned, not measured Elo.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
