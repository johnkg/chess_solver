import 'package:flutter/material.dart';

import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'board_view.dart';
import 'layout.dart';
import 'theme.dart';

/// A board snapshot for one mistake in the game review. "At the time" shows
/// the position when you moved, with your move in red and the better move in
/// green; "What happened" shows the board after your move and the reply that
/// punished it.
class ReviewSnapshot extends StatefulWidget {
  const ReviewSnapshot({super.key, required this.entry, this.flipped = false});

  final ReviewEntry entry;

  /// True when the player was Black, so the board is drawn from their side.
  final bool flipped;

  @override
  State<ReviewSnapshot> createState() => _ReviewSnapshotState();
}

class _ReviewSnapshotState extends State<ReviewSnapshot> {
  bool _after = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final mistake = entry.mistake!;
    final before = Position.fromFen(entry.fen);
    final colors = context.board;
    final theme = Theme.of(context);
    final canShowAfter = mistake.reply != null;
    final after = before.makeMove(mistake.played);
    final showAfter = _after && canShowAfter;

    final Position shown = showAfter ? after : before;
    final arrows = showAfter
        ? [BoardArrow(mistake.reply!.from, mistake.reply!.to, color: colors.played)]
        : [
            BoardArrow(mistake.played.from, mistake.played.to, color: colors.played),
            BoardArrow(mistake.best.from, mistake.best.to, color: colors.best),
          ];
    final caption = showAfter
        ? 'After ${entry.san}, ${san(after, mistake.reply!)} (red) is the reply.'
        : 'You played ${entry.san} (red). Better was ${san(before, mistake.best)} (green).';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${entry.number} ${entry.san}', style: theme.textTheme.titleSmall),
        gapSmall,
        if (canShowAfter)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('At the time')),
              ButtonSegment(value: true, label: Text('What happened')),
            ],
            selected: {_after},
            onSelectionChanged: (s) => setState(() => _after = s.first),
          ),
        gapSmall,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Semantics(
              label: caption,
              child: BoardView(
                position: shown,
                flipped: widget.flipped,
                lastMove: showAfter
                    ? {mistake.played.from, mistake.played.to}
                    : const {},
                arrows: arrows,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: theme.textTheme.bodyMedium),
        gapTiny,
        Text(mistake.text),
      ],
    );
  }
}
