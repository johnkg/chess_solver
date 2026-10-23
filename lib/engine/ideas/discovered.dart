import 'dart:math' as math;

import '../attacks.dart';
import '../insight.dart';
import '../move.dart';
import '../piece.dart';
import '../position.dart';

/// Gains (centipawns, best first) of targets the piece now on [to] newly
/// attacks and could win.
List<int> _moverGains(Position pos, Position next, int to, int s) {
  final forker = next.squares[to];
  final gains = <int>[];
  for (final t in attackedSquares(next, to)) {
    final p = next.squares[t];
    if (p == empty || pieceColor(p) == s || pieceType(p) == king) continue;
    if (attackersOf(pos, t, s).isNotEmpty) continue;
    final defended = attackersOf(next, t, 1 - s).isNotEmpty;
    final g = defended
        ? attackValue(pieceType(p)) - attackValue(pieceType(forker))
        : attackValue(pieceType(p));
    if (g > 0) gains.add(g);
  }
  gains.sort((a, b) => b.compareTo(a));
  return gains;
}

/// Two pieces give check at once: it cannot be blocked or captured, so the
/// king must move.
List<Insight> detectDoubleCheck(Position pos, Move m, Position next) {
  if (!next.inCheck || next.legalMoves().isEmpty) return const [];
  final s = pos.turn;
  final k = next.kingSquare(1 - s);
  final atk = attackersOf(next, k, s);
  if (atk.length < 2) return const [];
  final a = atk[0];
  final b = atk[1];
  return [
    Insight(
      idea: Idea.doubleCheck,
      move: m,
      squares: [a, b, k],
      gain: 0,
      level: 4,
      text: 'Double check: the ${pieceName(pieceType(next.squares[a]))} on '
          '${squareName(a)} and the ${pieceName(pieceType(next.squares[b]))} '
          'on ${squareName(b)} both attack the king on ${squareName(k)}. Two '
          'checks cannot be blocked or captured at once, so the king must '
          'move.',
    ),
  ];
}

/// Moving a piece uncovers a bishop, rook or queen behind it that now
/// attacks something.
List<Insight> detectDiscovered(Position pos, Move m, Position next) {
  if (m.flag == Move.castleKing || m.flag == Move.castleQueen) {
    return const [];
  }
  final s = pos.turn;
  final to = m.to;

  // (slider, target, gain); gain is null when the target is the king.
  final disc = <(int, int, int?)>[];
  for (var x = 0; x < 64; x++) {
    final p = next.squares[x];
    if (x == to || p == empty || pieceColor(p) != s) continue;
    final ty = pieceType(p);
    if (ty != bishop && ty != rook && ty != queen) continue;
    final before = attackedSquares(pos, x).toSet();
    for (final t in attackedSquares(next, x)) {
      final q = next.squares[t];
      if (q == empty || pieceColor(q) == s || before.contains(t)) continue;
      if (pieceType(q) == king) {
        disc.add((x, t, null));
      } else {
        final defended = attackersOf(next, t, 1 - s).isNotEmpty;
        final g = defended
            ? attackValue(pieceType(q)) - attackValue(ty)
            : attackValue(pieceType(q));
        if (g > 0) disc.add((x, t, g));
      }
    }
  }
  if (disc.isEmpty) return const [];

  final who = colorName(s);
  final opp = colorName(1 - s);
  final piece = pieceName(pieceType(pos.squares[m.from]));

  var net = 0;
  final isCapture = pos.squares[to] != empty || m.flag == Move.enPassant;
  if (isCapture && m.promotion == 0) net = math.max(net, seeCapture(pos, m));
  final own = _moverGains(pos, next, to, s);
  if (own.isNotEmpty) net = math.max(net, own.first);

  for (final (x, t, g) in disc) {
    if (g != null) continue;
    final slider = pieceName(pieceType(next.squares[x]));
    final tail = net > 0
        ? 'so the $piece is free to win material on ${squareName(to)} at the '
            'same time.'
        : 'so $who gains a tempo.';
    return [
      Insight(
        idea: Idea.discoveredAttack,
        move: m,
        squares: [x, t, to],
        gain: math.max(net, 0),
        level: 4,
        text: 'Moving the $piece uncovers the $slider on ${squareName(x)}, '
            'which checks the king on ${squareName(t)}. $opp must answer the '
            'check, $tail',
      ),
    ];
  }

  var bx = -1;
  var bt = -1;
  var bg = -1;
  for (final (x, t, g) in disc) {
    if (g! > bg) {
      bx = x;
      bt = t;
      bg = g;
    }
  }
  final slider = pieceName(pieceType(next.squares[bx]));
  final target =
      '${pieceName(pieceType(next.squares[bt]))} on ${squareName(bt)}';

  if (next.inCheck) {
    return [
      Insight(
        idea: Idea.discoveredAttack,
        move: m,
        squares: [bx, bt, to],
        gain: bg,
        level: 4,
        text: 'Moving the $piece gives check and uncovers the $slider on '
            '${squareName(bx)}, which attacks the $target. $opp must answer '
            'the check, so there is no time to save it.',
      ),
    ];
  }
  if (net <= 0) return const [];
  return [
    Insight(
      idea: Idea.discoveredAttack,
      move: m,
      squares: [bx, bt, to],
      gain: math.min(bg, net),
      level: 4,
      text: 'Moving the $piece uncovers the $slider on ${squareName(bx)}, '
          'which now attacks the $target, while the $piece makes a threat of '
          'its own. $opp cannot meet both.',
    ),
  ];
}
