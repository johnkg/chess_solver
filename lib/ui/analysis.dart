import 'package:flutter/material.dart';

import '../engine/eval.dart';
import '../engine/explainer.dart';
import '../engine/mistakes.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/san.dart';
import '../engine/search.dart';
import 'board_view.dart';

const Color _bestColor = Color(0xE61F7A4D);
const Color _playedColor = Color(0xE6B8412F);

/// A written verdict on a position or a move, tied to the position it
/// describes (by FEN) so a screen can hide it once the board moves on.
class Analysis {
  const Analysis({
    required this.fen,
    required this.text,
    this.arrows = const [],
    this.move,
  });

  /// Position the text is about.
  final String fen;
  final String text;
  final List<BoardArrow> arrows;

  /// The move being recommended, for a hint.
  final Move? move;
}

String _changeWords(Position pos, Move m) {
  final sign = pos.turn == white ? 1 : -1;
  final d = evalTerms(pos.makeMove(m)) - evalTerms(pos);
  final parts = <String>[
    if (sign * d.center >= 10) 'controls more of the center',
    if (sign * d.development >= 10) 'brings a piece into play',
    if (sign * d.kingSafety >= 10) 'makes the king safer',
    if (sign * d.material >= 100) 'wins material',
  ];
  if (parts.isEmpty) return 'No named idea here: it simply scores best.';
  return 'No named tactic here, but it ${parts.join(' and ')}.';
}

/// What to play in [pos] and why. [pos] must have a legal move.
Analysis analysePosition(Position pos, {int depth = 3}) {
  final lines = <String>[];
  final Move move;
  final mate = findMate(pos, 3);
  if (mate != null) {
    move = mate.move;
    lines.add('${san(pos, move)} forces checkmate in ${mate.moves}.');
  } else {
    move = bestMove(pos, depth)!.move;
    lines.add('Best move: ${san(pos, move)}.');
  }
  final why = explainVerified(pos, move);
  if (why.isEmpty) {
    lines.add(_changeWords(pos, move));
  } else {
    lines.addAll(why.map((i) => i.text));
  }
  return Analysis(
    fen: pos.toFen(),
    text: lines.join('\n\n'),
    arrows: [BoardArrow(move.from, move.to, color: _bestColor)],
    move: move,
  );
}

/// Why [played] (made in [before]) is good or bad. The result is about the
/// position after the move.
Analysis critiqueMove(Position before, Move played, {int depth = 3}) =>
    critiqueWith(before, played, explainMistake(before, played, depth: depth));

/// Same as [critiqueMove] for a [mistake] already worked out.
Analysis critiqueWith(Position before, Move played, Mistake? mistake) {
  final after = before.makeMove(played);
  final lines = <String>[];
  final arrows = <BoardArrow>[
    BoardArrow(played.from, played.to, color: _playedColor),
  ];
  if (mistake != null) {
    lines.add(mistake.text);
    arrows.add(BoardArrow(mistake.best.from, mistake.best.to, color: _bestColor));
  } else {
    lines.add('${san(before, played)} is a fine move.');
    lines.addAll(explainVerified(before, played).map((i) => i.text));
  }
  return Analysis(fen: after.toFen(), text: lines.join('\n\n'), arrows: arrows);
}
