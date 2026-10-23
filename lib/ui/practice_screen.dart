import 'package:flutter/material.dart';

import '../engine/piece.dart';
import '../engine/position.dart';
import '../puzzles/library.dart';
import 'labels.dart';
import 'progress_store.dart';
import 'puzzle_screen.dart';

/// Puzzles grouped by difficulty tier, with a tick on solved ones.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.progress});

  final ProgressStore progress;

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
