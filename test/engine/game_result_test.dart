import 'package:chess_solver/engine/game_result.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = Position.start();
  // Fool's mate: White is checkmated.
  final whiteMated = Position.fromFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
  final stalemate = Position.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');

  double? score(Position pos, int player,
          {bool drawn = false, bool resigned = false, int? flagged}) =>
      playerScore(pos: pos, player: player, drawn: drawn, resigned: resigned, flagged: flagged);

  test('no score while the game goes on', () {
    expect(score(start, white), isNull);
  });

  test('checkmate scores for the side that mated', () {
    expect(score(whiteMated, white), 0);
    expect(score(whiteMated, black), 1);
  });

  test('stalemate and rule draws score half', () {
    expect(score(stalemate, white), 0.5);
    expect(score(start, white, drawn: true), 0.5);
  });

  test('resigning loses, even on a won position', () {
    expect(score(whiteMated, black, resigned: true), 0);
  });

  test('running out of time loses for that side only', () {
    expect(score(start, white, flagged: white), 0);
    expect(score(start, white, flagged: black), 1);
  });

  test('ratingChangeNote shows the sign', () {
    expect(ratingChangeNote(1200, 1215), 'Rating 1215 (+15).');
    expect(ratingChangeNote(1200, 1188), 'Rating 1188 (-12).');
    expect(ratingChangeNote(1200, 1200), 'Rating 1200 (+0).');
  });
}
