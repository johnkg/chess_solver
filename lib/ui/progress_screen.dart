import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/achievements.dart';
import '../engine/daily.dart';
import '../engine/insight.dart';
import '../engine/pgn.dart';
import '../engine/rating.dart';
import '../engine/review.dart';
import '../lessons/lessons.dart';
import '../puzzles/library.dart';
import 'game_viewer.dart';
import 'labels.dart';
import 'line_trainer.dart' show lineProgressId;
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

const Set<Idea> _mateIdeas = {Idea.checkmate, Idea.backRankMate, Idea.smotheredMate, Idea.doubleCheck};

/// Boils the saved progress down to the numbers the badges need.
ProgressStats statsOf(ProgressStore progress) {
  final solved = [for (final p in puzzleLibrary) if (progress.isSolved(p.id)) p];
  return ProgressStats(
    puzzlesSolved: solved.length,
    matesSolved: solved.where((p) => p.mateIn > 0 || _mateIdeas.contains(p.idea)).length,
    bestDailyStreak: longestStreak(progress.dailyDays),
    gamesPlayed: progress.games.length,
    wins: progress.games.where((g) => g.score == 1).length,
    peakRating: progress.peakRating,
    linesLearned: lessons.where((l) => l.kind == LessonKind.line && progress.isSolved(lineProgressId(l))).length,
    rushBest: progress.rushBest,
    puzzlesLearned: progress.puzzlesLearned,
  );
}

/// App-bar button that opens the [ProgressScreen].
class ProgressButton extends StatelessWidget {
  const ProgressButton({super.key, required this.progress});

  final ProgressStore progress;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Your progress',
        icon: const Icon(Icons.insights_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProgressScreen(progress: progress)),
        ),
      );
}

/// Everything in one place: rating over time, puzzles by theme, streaks,
/// badges and the games you can review.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.progress, this.now});

  final ProgressStore progress;

  /// Clock for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: progress,
          builder: (context, _) {
            final today = dayNumber(now?.call() ?? DateTime.now());
            final stats = statsOf(progress);
            final badges = badgesFor(stats);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Summary(progress: progress, stats: stats, today: today),
                const SectionLabel('Rating'),
                _RatingHistory(games: progress.games),
                const SectionLabel('Puzzles by theme'),
                _Themes(progress: progress),
                SectionLabel('Badges · ${badges.where((b) => b.earned).length} of ${badges.length}'),
                for (final b in badges) _BadgeRow(badge: b),
                const SectionLabel('Games to review'),
                _SavedGames(progress: progress),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.progress, required this.stats, required this.today});

  final ProgressStore progress;
  final ProgressStats stats;
  final int today;

  @override
  Widget build(BuildContext context) {
    final streak = dailyStreak(progress.dailyDays, today);
    final due = progress.dueForReview(today).length;
    final tiles = [
      ('Puzzles', '${stats.puzzlesSolved}/${puzzleLibrary.length}'),
      ('Daily streak', '$streak'),
      ('Best streak', '${stats.bestDailyStreak}'),
      ('Rating', '${progress.rating}'),
      ('Games', '${stats.gamesPlayed}'),
      ('Rush best', '${stats.rushBest}'),
      ('Reviews due', '$due'),
      ('Mastered', '${stats.puzzlesLearned}'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final (label, value) in tiles) _Tile(label: label, value: value)],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: text.titleLarge?.copyWith(fontFamily: monoFamily)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Line chart of the rating after each game.
class _RatingHistory extends StatelessWidget {
  const _RatingHistory({required this.games});

  final List<GameRecord> games;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (games.length < 2) {
      return CoachCard(
        text: games.isEmpty
            ? 'Play a rated game to start your rating chart. You start at $startRating.'
            : 'One game so far. Play another to see the chart.',
      );
    }
    final shown = games.length > 30 ? games.sublist(games.length - 30) : games;
    final values = [startRating, for (final g in shown) g.ratingAfter];
    return Semantics(
      label: 'Rating after each game, from ${values.first} to ${values.last}',
      child: Container(
        height: 140,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: CustomPaint(
          painter: _ChartPainter(values, scheme.primary, scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.line, this.label);

  final List<int> values;
  final Color line;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final span = max(hi - lo, 40);
    Offset at(int i) => Offset(
          22 + (size.width - 22) * i / (values.length - 1),
          size.height - (values[i] - lo) / span * (size.height - 8) - 4,
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = line);
    void tag(String text, double y) {
      final p = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: label, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset(0, y.clamp(0, size.height - p.height)));
    }

    tag('$hi', 0);
    tag('$lo', size.height - 12);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values || old.line != line;
}

class _Themes extends StatelessWidget {
  const _Themes({required this.progress});

  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final total = <String, int>{};
    final done = <String, int>{};
    for (final p in puzzleLibrary) {
      final k = weakKey(p.idea);
      total.update(k, (n) => n + 1, ifAbsent: () => 1);
      if (progress.isSolved(p.id)) done.update(k, (n) => n + 1, ifAbsent: () => 1);
    }
    final keys = total.keys.toList()..sort((a, b) => weakLabel(a).compareTo(weakLabel(b)));
    final scheme = Theme.of(context).colorScheme;
    final missed = progress.missed;
    return Column(
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(weakLabel(k))),
                    if ((missed[k] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('missed ${missed[k]}', style: TextStyle(color: context.coach.bad, fontSize: 12)),
                      ),
                    Text('${done[k] ?? 0}/${total[k]}', style: const TextStyle(fontFamily: monoFamily)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (done[k] ?? 0) / total[k]!,
                    minHeight: 6,
                    color: context.coach.good,
                    backgroundColor: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${badge.title}, ${badge.earned ? 'earned' : '${badge.current} of ${badge.target}'}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badge.earned ? context.coach.goodBg : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                badge.earned ? Icons.emoji_events : Icons.emoji_events_outlined,
                color: badge.earned ? context.coach.good : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge.title, style: text.titleSmall),
                    Text(badge.description, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    if (!badge.earned) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: badge.fraction, minHeight: 5, backgroundColor: scheme.outline),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                badge.earned ? 'Earned' : '${badge.current}/${badge.target}',
                style: text.labelMedium?.copyWith(fontFamily: monoFamily),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedGames extends StatelessWidget {
  const _SavedGames({required this.progress});

  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    final games = <PgnGame>[];
    for (final text in progress.savedGames) {
      try {
        games.add(parsePgn(text));
      } on Object {
        // A saved game that no longer parses is skipped.
      }
    }
    if (games.isEmpty) {
      return const CoachCard(
        text: 'Finish a game in the Play tab and it shows up here, ready to review move by move.',
      );
    }
    return Column(
      children: [
        for (final g in games)
          RowCard(
            leading: const Icon(Icons.history_edu_outlined),
            title: '${g.white} vs ${g.black}',
            subtitle: '${g.headers['Date'] ?? ''} · ${(g.moves.length + 1) ~/ 2} moves · ${g.result}',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => GameViewer(game: g, progress: progress)),
            ),
          ),
      ],
    );
  }
}
