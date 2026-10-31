import 'package:flutter/material.dart';

import 'layout.dart';

/// First / back / next / last buttons for stepping through a game or line.
/// [ply] is the position shown (0 = start); [lastPly] is the final one.
class StepControls extends StatelessWidget {
  const StepControls({
    super.key,
    required this.ply,
    required this.lastPly,
    required this.onGoTo,
  });

  final int ply;
  final int lastPly;
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final atStart = ply == 0;
    final atEnd = ply == lastPly;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          tooltip: 'Start',
          onPressed: atStart ? null : () => onGoTo(0),
          icon: const Icon(Icons.first_page),
        ),
        gapSmallHorizontal,
        IconButton.outlined(
          tooltip: 'Back',
          onPressed: atStart ? null : () => onGoTo(ply - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        gapSmallHorizontal,
        IconButton.filled(
          tooltip: 'Next move',
          onPressed: atEnd ? null : () => onGoTo(ply + 1),
          icon: const Icon(Icons.chevron_right),
        ),
        gapSmallHorizontal,
        IconButton.outlined(
          tooltip: 'End',
          onPressed: atEnd ? null : () => onGoTo(lastPly),
          icon: const Icon(Icons.last_page),
        ),
      ],
    );
  }
}

/// The Hint / Restart button pair under a trainer's board. The hint button
/// says "Show move" once a hint has been given; pass a null [onHint] to
/// disable it (not your turn).
class HintRestartRow extends StatelessWidget {
  const HintRestartRow({
    super.key,
    required this.onHint,
    required this.hintGiven,
    required this.onRestart,
    required this.restartLabel,
  });

  final VoidCallback? onHint;
  final bool hintGiven;
  final VoidCallback onRestart;
  final String restartLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: wrapSpacing,
      runSpacing: wrapSpacing,
      children: [
        FilledButton.icon(
          onPressed: onHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(hintGiven ? 'Show move' : 'Hint'),
        ),
        OutlinedButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.replay),
          label: Text(restartLabel),
        ),
      ],
    );
  }
}
