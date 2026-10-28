import 'package:flutter/material.dart';

import '../engine/daily.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/weakspots.dart';
import '../lessons/drills.dart';
import '../puzzles/library.dart';
import 'drill_screen.dart';
import 'labels.dart';
import 'progress_store.dart';
import 'puzzle_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Puzzles grouped by difficulty tier, with a tick on solved ones.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.progress, this.now});

  final ProgressStore progress;

  /// Clock for tests; defaults to the real time.
  final DateTime Function()? now;

  Widget _daily(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dayNumber(now?.call() ?? DateTime.now());
    final puzzle = dailyPuzzle(puzzleLibrary, today);
    final done = progress.dailyDays.contains(today);
    final streak = dailyStreak(progress.dailyDays, today);
    final best = longestStreak(progress.dailyDays);
    final date = dateOfDay(today);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final kind = puzzle.mateIn > 0 ? 'Mate in ${puzzle.mateIn}' : 'Win material';
    return HeroCard(
      eyebrow: 'Daily puzzle · ${months[date.month - 1]} ${date.day}',
      title: done ? 'Solved today' : kind,
      body: streak == 0
          ? 'One puzzle a day. Solve today\'s to start a streak.'
          : '$streak-day streak${best > streak ? ' · best $best' : ''}. '
              '${done ? 'Come back tomorrow for a new one.' : 'Solve today\'s to keep it going.'}',
      action: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PuzzleScreen(puzzle: puzzle, progress: progress, dailyDay: today),
              ),
            ),
            icon: Icon(done ? Icons.replay : Icons.today),
            label: Text(done ? 'Play it again' : 'Solve today\'s puzzle'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 6; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: i == 0 ? 'Today' : '$i day${i == 1 ? '' : 's'} ago',
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: progress.dailyDays.contains(today - i)
                            ? scheme.primary
                            : scheme.surface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weakSpots(BuildContext context) {
    final spots = weakest(progress.missed, puzzleLibrary);
    final next = nextWeakPuzzle(puzzleLibrary, progress.missed, progress.solved);
    if (spots.isEmpty) {
      return const CoachCard(
        title: 'Your weak spots',
        text: 'None yet. Ideas you miss in a game or a puzzle show up here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          amber: true,
          eyebrow: 'Drill what you miss',
          title: 'Your weak spots',
          body: 'Puzzles that practise the ideas you miss most.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: next == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PuzzleScreen(
                          puzzle: next,
                          progress: progress,
                          weakMode: true,
                        ),
                      ),
                    ),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Practice weak spots'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in spots)
              Chip(
                label: Text('${weakLabel(e.key)} · missed ${e.value}'),
                backgroundColor: context.coach.badBg,
                labelStyle: TextStyle(
                  color: context.coach.bad,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiers = {for (final p in puzzleLibrary) p.tier}.toList()..sort();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: progress,
          builder: (context, _) {
            final done = puzzleLibrary.where((p) => progress.isSolved(p.id)).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Solved $done of ${puzzleLibrary.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: puzzleLibrary.isEmpty ? 0 : done / puzzleLibrary.length,
                    minHeight: 6,
                    color: context.coach.good,
                    backgroundColor: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                _daily(context),
                const SizedBox(height: 12),
                _weakSpots(context),
                const SectionLabel('Training positions'),
                for (final d in drills)
                  RowCard(
                    leading: Icon(
                      progress.isSolved(d.id)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: progress.isSolved(d.id)
                          ? context.coach.good
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: d.title,
                    subtitle: '${phaseLabel(d.phase)} · you play ${colorName(d.side)}',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DrillScreen(drill: d, progress: progress),
                      ),
                    ),
                  ),
                for (final tier in tiers) ...[
                  SectionLabel(tierTitle(tier)),
                  for (final p in puzzleLibrary.where((p) => p.tier == tier))
                    RowCard(
                      leading: Icon(
                        progress.isSolved(p.id)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: progress.isSolved(p.id)
                            ? context.coach.good
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: p.mateIn > 0 ? 'Mate in ${p.mateIn}' : 'Win material',
                      subtitle: '${colorName(Position.fromFen(p.fen).turn)} to move',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PuzzleScreen(puzzle: p, progress: progress),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
