import 'package:flutter/material.dart';

import '../engine/daily.dart';
import '../engine/drill.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/puzzle.dart';
import '../engine/review.dart' show weakKey;
import '../engine/rush.dart';
import '../engine/weakspots.dart';
import '../lessons/drills.dart';
import '../lessons/lessons.dart';
import '../puzzles/library.dart';
import 'drill_screen.dart';
import 'labels.dart';
import 'layout.dart';
import 'line_trainer.dart';
import 'progress_screen.dart';
import 'progress_store.dart';
import 'puzzle_screen.dart';
import 'repertoire_trainer.dart';
import 'rush_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Puzzles grouped by difficulty tier, with a tick on solved ones.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.progress, this.now});

  final ProgressStore progress;

  /// Clock for tests; defaults to the real time.
  final DateTime Function()? now;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  ProgressStore get progress => widget.progress;
  DateTime Function()? get now => widget.now;

  /// A [weakKey] to show only that theme's puzzles in the list and the path.
  String? _theme;

  int get _today => dayNumber(now?.call() ?? DateTime.now());

  bool _inTheme(Puzzle p) => _theme == null || weakKey(p.idea) == _theme;

  void _openPuzzle(Puzzle p, {Puzzle? Function(Set<String>)? next, String label = 'Next puzzle'}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(
          puzzle: p,
          progress: progress,
          nextPuzzle: next,
          nextLabel: label,
          today: _today,
        ),
      ),
    );
  }

  Puzzle? _pathNext(Set<String> seen) =>
      nextPathPuzzle(puzzleLibrary, progress.solved, only: (p) => _inTheme(p) && !seen.contains(p.id));

  Puzzle? _dueNext(Set<String> seen) {
    for (final id in progress.dueForReview(_today)) {
      if (seen.contains(id)) continue;
      for (final p in puzzleLibrary) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Widget _review(BuildContext context) {
    final first = _dueNext(const {});
    final n = progress.dueForReview(_today).length;
    if (first == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HeroCard(
        eyebrow: 'Spaced review',
        title: '${countOf(n, 'puzzle')} to review',
        body: 'Puzzles you missed come back after a day, then 3, 7, 14 and 30 days '
            'until you solve them cleanly every time.',
        action: FilledButton.icon(
          onPressed: () => _openPuzzle(first, next: _dueNext, label: 'Next review'),
          icon: const Icon(Icons.history),
          label: const Text('Start review'),
        ),
      ),
    );
  }

  Widget _tools(BuildContext context) {
    final path = _pathNext(const {});
    final themes = <String, int>{};
    for (final p in puzzleLibrary) {
      themes.update(weakKey(p.idea), (n) => n + 1, ifAbsent: () => 1);
    }
    final keys = themes.keys.toList()..sort((a, b) => weakLabel(a).compareTo(weakLabel(b)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: path == null ? null : () => _openPuzzle(path, next: _pathNext),
                icon: const Icon(Icons.route),
                label: Text(path == null ? 'All solved' : 'Next for you'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => RushScreen(progress: progress)),
                ),
                icon: const Icon(Icons.bolt),
                label: Text(progress.rushBest > 0 ? 'Puzzle Rush · best ${progress.rushBest}' : 'Puzzle Rush'),
              ),
            ),
          ],
        ),
        gapMedium,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All themes'),
                  selected: _theme == null,
                  onSelected: (_) => setState(() => _theme = null),
                ),
              ),
              for (final k in keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${weakLabel(k)} · ${themes[k]}'),
                    selected: _theme == k,
                    onSelected: (_) => setState(() => _theme = _theme == k ? null : k),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

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
                    message: i == 0 ? 'Today' : '${countOf(i, 'day')} ago',
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

  Widget _check(BuildContext context, bool done) => Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? context.coach.good : Theme.of(context).colorScheme.onSurfaceVariant,
      );

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
        gapMedium,
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
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [ProgressButton(progress: progress), SettingsButton(progress: progress)],
      ),
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
                gapMedium,
                _review(context),
                _weakSpots(context),
                gapMedium,
                _tools(context),
                for (final (title, level) in [('Opening lines', 8), ('Famous games', 7)]) ...[
                  SectionLabel(title),
                  for (final l in lessons.where((l) => l.kind == LessonKind.line && l.level == level))
                    RowCard(
                      leading: _check(context, progress.isSolved(lineProgressId(l))),
                      title: l.title,
                      subtitle: 'You play ${l.side == 'black' ? 'Black' : 'White'} · ${(l.line.length + 1) ~/ 2} moves'
                          '${l.branches.isEmpty ? '' : ' · ${l.branches.length + 1} variations'}',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => l.branches.isEmpty
                              ? LineTrainer(lesson: l, progress: progress)
                              : RepertoireTrainer(lesson: l, progress: progress),
                        ),
                      ),
                    ),
                ],
                for (final phase in ['middlegame', 'endgame']) ...[
                  SectionLabel('${phaseLabel(phase)} training'),
                  for (final d in drills.where((d) => d.phase == phase))
                    RowCard(
                      leading: _check(context, progress.isSolved(d.id)),
                      title: d.title,
                      subtitle: d.goal == DrillGoal.find
                          ? 'Spot it on the board'
                          : 'You play ${colorName(d.side)} against the engine',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DrillScreen(drill: d, progress: progress),
                        ),
                      ),
                    ),
                ],
                for (final tier in tiers) ...[
                  if (puzzleLibrary.any((p) => p.tier == tier && _inTheme(p))) SectionLabel(tierTitle(tier)),
                  for (final p in puzzleLibrary.where((p) => p.tier == tier && _inTheme(p)))
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
