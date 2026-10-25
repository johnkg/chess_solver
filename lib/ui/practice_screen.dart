import 'package:flutter/material.dart';

import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/weakspots.dart';
import '../puzzles/library.dart';
import 'labels.dart';
import 'progress_store.dart';
import 'puzzle_screen.dart';

/// Puzzles grouped by difficulty tier, with a tick on solved ones.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.progress});

  final ProgressStore progress;

  Widget _weakSpots(BuildContext context) {
    final spots = weakest(progress.missed, puzzleLibrary);
    final next = nextWeakPuzzle(puzzleLibrary, progress.missed, progress.solved);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your weak spots', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (spots.isEmpty)
              const Text(
                'None yet. Ideas you miss in a game or a puzzle show up here.',
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final e in spots)
                    Chip(label: Text('${weakLabel(e.key)} · missed ${e.value}')),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
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
            ],
          ],
        ),
      ),
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Solved $done of ${puzzleLibrary.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _weakSpots(context),
                for (final tier in tiers) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(tierTitle(tier), style: theme.textTheme.titleSmall),
                  ),
                  for (final p in puzzleLibrary.where((p) => p.tier == tier))
                    ListTile(
                      leading: Icon(
                        progress.isSolved(p.id)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(p.mateIn > 0 ? 'Mate in ${p.mateIn}' : 'Win material'),
                      subtitle: Text(
                        '${colorName(Position.fromFen(p.fen).turn)} to move',
                      ),
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
