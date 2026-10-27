import 'package:flutter/material.dart';

import '../engine/piece.dart';
import '../engine/position.dart';
import 'theme.dart';

/// An arrow drawn over the board, from one square to another.
class BoardArrow {
  const BoardArrow(this.from, this.to, {this.color = const Color(0xE61F7A4D)});

  final int from;
  final int to;
  final Color color;
}

/// Filled glyphs for both colours; the variation selector keeps platforms
/// from swapping the pawn for an emoji.
const Map<int, String> _glyphs = {
  pawn: '♟︎',
  knight: '♞︎',
  bishop: '♝︎',
  rook: '♜︎',
  queen: '♛︎',
  king: '♚︎',
};

const List<Shadow> _whiteOutline = [
  Shadow(color: Colors.black, blurRadius: 1, offset: Offset(1, 0)),
  Shadow(color: Colors.black, blurRadius: 1, offset: Offset(-1, 0)),
  Shadow(color: Colors.black, blurRadius: 1, offset: Offset(0, 1)),
  Shadow(color: Colors.black, blurRadius: 1, offset: Offset(0, -1)),
];

/// Draws a position. Square numbers follow the engine: a1 = 0 ... h8 = 63.
///
/// Tapping a square calls [onTap] with its number. [targets] get a dot (a
/// ring when a piece stands there), [highlights] a blue tint, [lastMove] and
/// [selected] a yellow tint.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.position,
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.highlights = const {},
    this.lastMove = const {},
    this.arrows = const [],
    this.onTap,
  });

  final Position position;

  /// True draws Black at the bottom.
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Set<int> highlights;
  final Set<int> lastMove;
  final List<BoardArrow> arrows;
  final void Function(int square)? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.board;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          final cell = size / 8;
          final children = <Widget>[];
          for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
              final sq = flipped ? squareOf(row, 7 - col) : squareOf(7 - row, col);
              children.add(
                Positioned(
                  left: col * cell,
                  top: row * cell,
                  width: cell,
                  height: cell,
                  child: _buildCell(colors, sq, cell, row, col),
                ),
              );
            }
          }
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ArrowPainter(
                    arrows: arrows,
                    cell: cell,
                    flipped: flipped,
                  ),
                ),
              ),
            ),
          );
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: children),
          );
        },
      ),
    );
  }

  Widget _buildCell(BoardColors colors, int sq, double cell, int row, int col) {
    final dark = (rankOf(sq) + fileOf(sq)) % 2 == 0;
    final piece = position.squares[sq];
    final labelColor = dark ? colors.light : colors.dark;
    final labelStyle = TextStyle(
      fontSize: cell * 0.17,
      fontWeight: FontWeight.bold,
      color: labelColor,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(sq),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: dark ? colors.dark : colors.light),
          if (lastMove.contains(sq)) ColoredBox(color: colors.lastMove),
          if (highlights.contains(sq)) ColoredBox(color: colors.pattern),
          if (selected == sq) ColoredBox(color: colors.selected),
          if (row == 7)
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('abcdefgh'[fileOf(sq)], style: labelStyle),
            ),
          if (col == 0)
            Positioned(
              left: 2,
              top: 0,
              child: Text('${rankOf(sq) + 1}', style: labelStyle),
            ),
          if (piece != empty) Center(child: _pieceGlyph(piece, cell)),
          if (targets.contains(sq))
            Center(child: piece == empty ? _dot(cell) : _ring(cell)),
        ],
      ),
    );
  }

  Widget _pieceGlyph(int piece, double cell) {
    final isWhite = pieceColor(piece) == white;
    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: EdgeInsets.all(cell * 0.04),
        child: Text(
          _glyphs[pieceType(piece)]!,
          style: TextStyle(
            fontSize: cell * 0.8,
            height: 1.0,
            color: isWhite ? Colors.white : Colors.black,
            shadows: isWhite ? _whiteOutline : null,
          ),
        ),
      ),
    );
  }

  Widget _dot(double cell) => Container(
        width: cell * 0.3,
        height: cell * 0.3,
        decoration: const BoxDecoration(
          color: Color(0x55000000),
          shape: BoxShape.circle,
        ),
      );

  Widget _ring(double cell) => Container(
        width: cell * 0.9,
        height: cell * 0.9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x66000000), width: cell * 0.08),
        ),
      );
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.arrows,
    required this.cell,
    required this.flipped,
  });

  final List<BoardArrow> arrows;
  final double cell;
  final bool flipped;

  Offset _center(int sq) {
    final r = rankOf(sq);
    final f = fileOf(sq);
    final col = flipped ? 7 - f : f;
    final row = flipped ? r : 7 - r;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in arrows) {
      final from = _center(a.from);
      final to = _center(a.to);
      final delta = to - from;
      final length = delta.distance;
      if (length == 0) continue;
      final unit = delta / length;
      final normal = Offset(-unit.dy, unit.dx);
      final headLength = cell * 0.4;
      final headHalfWidth = cell * 0.22;

      final tip = to - unit * (cell * 0.1);
      final headBase = tip - unit * headLength;

      final shaft = Paint()
        ..color = a.color
        ..strokeWidth = cell * 0.15
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from + unit * (cell * 0.15), headBase, shaft);

      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          headBase.dx + normal.dx * headHalfWidth,
          headBase.dy + normal.dy * headHalfWidth,
        )
        ..lineTo(
          headBase.dx - normal.dx * headHalfWidth,
          headBase.dy - normal.dy * headHalfWidth,
        )
        ..close();
      canvas.drawPath(head, Paint()..color = a.color);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.arrows != arrows || old.cell != cell || old.flipped != flipped;
}
