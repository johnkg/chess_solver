import 'package:flutter/material.dart';

import '../engine/clock.dart';
import '../engine/piece.dart';
import 'piece_painter.dart';
import 'theme.dart';

/// One side's strip above or below the board: who it is, the pieces it has
/// captured (with the material lead, if any) and, when a clock is on, its time.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.name,
    required this.captured,
    required this.capturedColor,
    required this.lead,
    this.clockMs,
    this.active = false,
  });

  final String name;

  /// Piece types this side has captured, most valuable first.
  final List<int> captured;

  /// Colour of the captured pieces (the other side's colour).
  final int capturedColor;

  /// Material lead from captures, in pawns; shown only when positive.
  final int lead;

  /// Milliseconds left, or null when no clock is on.
  final int? clockMs;

  /// True while this side's clock is running.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final low = clockMs != null && clockMs! < 10000;
    return Semantics(
      container: true,
      label: '$name. Captured: ${captured.isEmpty ? 'nothing' : captured.length} pieces.'
          '${clockMs == null ? '' : ' Time left ${formatClock(clockMs!)}.'}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                  SizedBox(
                    height: 22,
                    child: Row(
                      children: [
                        _Pieces(types: captured, color: capturedColor),
                        if (lead > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('+$lead',
                                style: text.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (clockMs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? scheme.onSurface : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatClock(clockMs!),
                  style: TextStyle(
                    fontFamily: monoFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: low
                        ? context.coach.bad
                        : (active ? scheme.surface : scheme.onSurface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Captured pieces in a tight row; pieces of one kind overlap a little.
class _Pieces extends StatelessWidget {
  const _Pieces({required this.types, required this.color});

  final List<int> types;
  final int color;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    final children = <Widget>[];
    for (var i = 0; i < types.length; i++) {
      final sameNext = i + 1 < types.length && types[i + 1] == types[i];
      final piece = SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: PiecePainter(makePiece(types[i], color))),
      );
      children.add(sameNext
          ? Align(alignment: Alignment.centerLeft, widthFactor: 0.55, child: piece)
          : Padding(
              padding: EdgeInsets.only(right: i + 1 < types.length ? 4 : 0),
              child: piece,
            ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
