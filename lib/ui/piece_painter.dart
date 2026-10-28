import 'package:flutter/material.dart';

import '../engine/piece.dart';

/// Draws a chess piece as shaded vector art: a rounded body lit from the top
/// left, a soft glossy highlight, a dark outline and a shadow on the square.
/// Shapes are drawn in a 100 x 100 box and scaled to the cell.
class PiecePainter extends CustomPainter {
  const PiecePainter(this.piece, {this.flat = false});

  final int piece;

  /// Flat style: solid colours and an outline, no shading.
  final bool flat;

  static final Map<int, List<Path>> _shapes = {};

  static Path _rr(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  static Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  static List<Path> _build(int type) {
    final base = [_rr(22, 82, 78, 92, 4), _rr(27, 75, 73, 84, 3)];
    switch (type) {
      case pawn:
        return [
          ...base,
          Path()
            ..moveTo(42, 46)
            ..cubicTo(42, 58, 34, 66, 31, 76)
            ..lineTo(69, 76)
            ..cubicTo(66, 66, 58, 58, 58, 46)
            ..close(),
          _rr(37, 42, 63, 49, 3),
          _circle(50, 31, 11),
        ];
      case rook:
        return [
          ...base,
          Path()
            ..moveTo(33, 76)
            ..lineTo(38, 38)
            ..lineTo(62, 38)
            ..lineTo(67, 76)
            ..close(),
          Path()
            ..moveTo(30, 16)
            ..lineTo(30, 40)
            ..lineTo(70, 40)
            ..lineTo(70, 16)
            ..lineTo(61, 16)
            ..lineTo(61, 23)
            ..lineTo(55, 23)
            ..lineTo(55, 16)
            ..lineTo(45, 16)
            ..lineTo(45, 23)
            ..lineTo(39, 23)
            ..lineTo(39, 16)
            ..close(),
        ];
      case knight:
        return [
          ...base,
          Path()
            ..moveTo(30, 76)
            ..cubicTo(28, 60, 34, 50, 44, 42)
            ..cubicTo(38, 42, 33, 45, 28, 50)
            ..lineTo(21, 45)
            ..cubicTo(23, 33, 33, 22, 46, 18)
            ..lineTo(45, 8)
            ..lineTo(53, 14)
            ..cubicTo(55, 12, 57, 12, 59, 12)
            ..cubicTo(69, 16, 77, 28, 77, 46)
            ..cubicTo(77, 58, 73, 68, 73, 76)
            ..close(),
        ];
      case bishop:
        return [
          ...base,
          Path()
            ..moveTo(42, 56)
            ..cubicTo(42, 66, 34, 68, 31, 76)
            ..lineTo(69, 76)
            ..cubicTo(66, 68, 58, 66, 58, 56)
            ..close(),
          _rr(36, 50, 64, 57, 3),
          Path()..addOval(Rect.fromCenter(center: const Offset(50, 34), width: 24, height: 34)),
          _circle(50, 14, 4.5),
        ];
      case queen:
        return [
          ...base,
          _body(),
          _rr(36, 45, 64, 52, 3),
          Path()
            ..moveTo(32, 46)
            ..lineTo(24, 22)
            ..lineTo(38, 34)
            ..lineTo(44, 18)
            ..lineTo(50, 32)
            ..lineTo(56, 18)
            ..lineTo(62, 34)
            ..lineTo(76, 22)
            ..lineTo(68, 46)
            ..close(),
          _circle(24, 19, 3.6),
          _circle(44, 15, 3.6),
          _circle(56, 15, 3.6),
          _circle(76, 19, 3.6),
        ];
      default: // king
        return [
          ...base,
          _body(),
          _rr(36, 45, 64, 52, 3),
          Path()
            ..moveTo(34, 46)
            ..cubicTo(30, 34, 38, 28, 50, 28)
            ..cubicTo(62, 28, 70, 34, 66, 46)
            ..close(),
          _rr(46, 6, 54, 27, 2),
          _rr(40, 12, 60, 19, 2),
        ];
    }
  }

  static Path _body() => Path()
    ..moveTo(40, 50)
    ..cubicTo(40, 62, 33, 68, 30, 76)
    ..lineTo(70, 76)
    ..cubicTo(67, 68, 60, 62, 60, 50)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final type = pieceType(piece);
    final isWhite = pieceColor(piece) == white;
    final shapes = _shapes.putIfAbsent(type, () => _build(type));
    final box = const Rect.fromLTWH(0, 0, 100, 100);
    canvas.save();
    canvas.scale(size.shortestSide / 100);

    if (!flat) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(52, 91), width: 62, height: 9),
      Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    final fill = flat
        ? (Paint()..color = isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF101A19))
        : (Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 1.15,
        colors: isWhite
            ? const [Color(0xFFFFFFFF), Color(0xFFE9E2D0), Color(0xFFA39A84)]
            : const [Color(0xFF72828A), Color(0xFF2E383C), Color(0xFF0B1113)],
        stops: const [0, 0.5, 1],
      ).createShader(box));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = flat ? 2.2 : 1.7
      ..strokeJoin = StrokeJoin.round
      ..color = isWhite ? const Color(0xFF2B2A26) : const Color(0xFF000000);
    final gloss = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.65),
        radius: 0.55,
        colors: [
          Color(isWhite ? 0x99FFFFFF : 0x47FFFFFF),
          const Color(0x00FFFFFF),
        ],
      ).createShader(box);

    for (final p in shapes) {
      canvas.drawPath(p, fill);
    }
    if (!flat) {
      for (final p in shapes) {
        canvas.save();
        canvas.clipPath(p);
        canvas.drawRect(box, gloss);
        canvas.restore();
      }
    }
    for (final p in shapes) {
      canvas.drawPath(p, edge);
    }

    if (type == knight) {
      canvas.drawCircle(
        const Offset(55, 29),
        2.4,
        Paint()..color = isWhite ? const Color(0xFF2B2A26) : const Color(0xFFE8EDEE),
      );
    } else if (type == bishop) {
      canvas.drawLine(
        const Offset(55, 24),
        const Offset(46, 38),
        edge..strokeWidth = 2.2..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PiecePainter old) => old.piece != piece || old.flat != flat;
}
