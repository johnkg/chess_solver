import 'package:flutter/material.dart';

import '../engine/game_eval.dart';

/// Height of the eval bar under the board.
const double _barHeight = 22;

/// Height of the whole-game chart.
const double _chartHeight = 72;

/// White's colour in the bar and chart; Black's is the scheme's dark surface.
const Color _whiteSide = Color(0xFFF4F1EA);
const Color _blackSide = Color(0xFF2B2B2B);

/// A horizontal bar: White's share on the left, Black's on the right, and the
/// score as text. [score] is White's view (see [whiteScore]); null while it
/// is being worked out.
class EvalBar extends StatelessWidget {
  const EvalBar({super.key, required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final share = s == null ? 0.5 : whiteShare(s);
    final label = s == null ? '…' : scoreLabel(s);
    final whiteAhead = s == null || s >= 0;
    return Semantics(
      label: s == null ? 'Evaluation pending' : 'Evaluation $label',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: _barHeight,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(flex: (share * 1000).round(), child: const ColoredBox(color: _whiteSide)),
                  Expanded(flex: 1000 - (share * 1000).round(), child: const ColoredBox(color: _blackSide)),
                ],
              ),
              Align(
                alignment: whiteAhead ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: whiteAhead ? _blackSide : _whiteSide,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The evaluation over the whole game: White's share above, Black's below,
/// a line at the shown position, dots on the biggest swings. Tapping jumps
/// to that position. [scores] has one entry per position (null = not yet
/// worked out).
class EvalChart extends StatelessWidget {
  const EvalChart({
    super.key,
    required this.scores,
    required this.ply,
    required this.swings,
    required this.onGoTo,
  });

  final List<int?> scores;
  final int ply;

  /// Indexes of moves that swung the game (move i leads to position i + 1).
  final List<int> swings;
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final last = scores.length - 1;
        void jump(Offset at) {
          if (last <= 0) return;
          onGoTo((at.dx / box.maxWidth * last).round().clamp(0, last));
        }

        return GestureDetector(
          onTapDown: (d) => jump(d.localPosition),
          onHorizontalDragUpdate: (d) => jump(d.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              size: Size(box.maxWidth, _chartHeight),
              painter: _ChartPainter(
                scores: scores,
                ply: ply,
                swings: swings,
                marker: scheme.primary,
                swingColor: scheme.error,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.scores,
    required this.ply,
    required this.swings,
    required this.marker,
    required this.swingColor,
  });

  final List<int?> scores;
  final int ply;
  final List<int> swings;
  final Color marker;
  final Color swingColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _blackSide);
    final last = scores.length - 1;
    if (last < 1) return;
    double x(int i) => i / last * size.width;
    double y(int i) => (1 - whiteShare(scores[i] ?? 0)) * size.height;

    final known = [for (var i = 0; i <= last; i++) if (scores[i] != null) i];
    if (known.isNotEmpty) {
      final area = Path()..moveTo(x(known.first), size.height);
      for (final i in known) {
        area.lineTo(x(i), y(i));
      }
      area
        ..lineTo(x(known.last), size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = _whiteSide);
    }

    final mid = Paint()
      ..color = Colors.grey.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), mid);

    final dot = Paint()..color = swingColor;
    for (final i in swings) {
      if (i + 1 <= last && scores[i + 1] != null) canvas.drawCircle(Offset(x(i + 1), y(i + 1)), 3.5, dot);
    }

    canvas.drawLine(
      Offset(x(ply), 0),
      Offset(x(ply), size.height),
      Paint()
        ..color = marker
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.ply != ply || old.scores != scores || old.swings != swings;
}
