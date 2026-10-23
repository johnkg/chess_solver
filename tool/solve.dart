// ignore_for_file: avoid_print
// CLI: explain a position.
//   dart run tool/solve.dart "<fen>" [depth] [move-to-critique, e.g. e2e4]
//
// Prints the board, forced mate if any (up to mate in 3), the best move with
// the ideas that explain it, and the evaluation split into named terms.
import 'package:chess_solver/engine/eval.dart';
import 'package:chess_solver/engine/explainer.dart';
import 'package:chess_solver/engine/mistakes.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart';

void main(List<String> args) {
  final fen = args.isEmpty ? Position.startFen : args[0];
  final depth = args.length > 1 ? int.parse(args[1]) : 4;

  final Position pos;
  try {
    pos = Position.fromFen(fen);
  } on FormatException catch (e) {
    print('Bad FEN: ${e.message}');
    return;
  }

  print(pos.pretty());
  print('');
  print('${pos.turn == 0 ? 'White' : 'Black'} to move, '
      '${pos.legalMoves().length} legal moves'
      '${pos.inCheck ? ', in check' : ''}');

  if (pos.isCheckmate) {
    print('Checkmate.');
    return;
  }
  if (pos.isStalemate) {
    print('Stalemate.');
    return;
  }

  if (args.length > 2) {
    final played = pos.legalMoves().where((m) => m.uci == args[2]).firstOrNull;
    if (played == null) {
      print('Not a legal move here: ${args[2]}');
      return;
    }
    final mistake = explainMistake(pos, played, depth: depth);
    if (mistake != null) {
      print(mistake.text);
    } else {
      print('${args[2]} is a fine move.');
      for (final i in explainVerified(pos, played)) {
        print('  - ${i.text}');
      }
    }
    return;
  }

  final mate = findMate(pos, 3);
  if (mate != null) {
    print('Forced mate in ${mate.moves}: ${mate.move.uci}');
    for (final i in explainVerified(pos, mate.move)) {
      print('  - ${i.text}');
    }
  }

  final best = bestMove(pos, depth);
  if (best != null) {
    final after = evalTerms(pos.makeMove(best.move)) - evalTerms(pos);
    print('Best move (depth $depth): ${best.move.uci}  score ${best.score}');
    print('Changes (White view): $after');
    final why = explainVerified(pos, best.move);
    if (why.isEmpty) {
      print('Why: no named idea yet for this move.');
    } else {
      print('Why:');
      for (final i in why) {
        print('  - [${i.idea.name}${i.verified ? ', verified' : ''}] ${i.text}');
      }
    }
  }
  print('Eval now: ${evalTerms(pos)}');
}
