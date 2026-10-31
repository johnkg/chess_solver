import 'package:flutter/material.dart';

import '../engine/rating.dart';
import 'layout.dart';
import 'progress_store.dart';
import 'theme.dart';

/// Your rating from games against the engine: the number, your record and
/// the last results. Only games played without hints or take-backs count.
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.progress});

  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final games = progress.games;
        final wins = games.where((g) => g.score == 1).length;
        final draws = games.where((g) => g.score == 0.5).length;
        final losses = games.length - wins - draws;
        final recent = games.length > 10 ? games.sublist(games.length - 10) : games;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR RATING', style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  )),
                  Text(
                    '${progress.rating}',
                    style: text.headlineSmall?.copyWith(fontFamily: monoFamily),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      games.isEmpty
                          ? 'Play a game to get a rating (starts at $startRating).'
                          : '$wins W · $draws D · $losses L · peak ${progress.peakRating}',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: [for (final g in recent) _Dot(g)],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.game);

  final GameRecord game;

  @override
  Widget build(BuildContext context) {
    final c = context.coach;
    final scheme = Theme.of(context).colorScheme;
    final color = game.score == 1
        ? c.good
        : (game.score == 0 ? c.bad : scheme.onSurfaceVariant);
    return Tooltip(
      message: '${game.result} vs ${game.opponentElo} → ${game.ratingAfter}',
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          game.result,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: scheme.surface),
        ),
      ),
    );
  }
}
