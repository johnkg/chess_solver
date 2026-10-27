import 'package:chess_solver/engine/rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equal ratings expect half a point', () {
    expect(expectedScore(1200, 1200), closeTo(0.5, 1e-9));
    expect(expectedScore(1600, 1200), greaterThan(0.9));
    expect(expectedScore(1200, 1600), lessThan(0.1));
  });

  test('a win raises, a loss lowers, a draw between equals changes nothing', () {
    expect(updatedRating(1000, 1000, 1, games: 20), 1012);
    expect(updatedRating(1000, 1000, 0, games: 20), 988);
    expect(updatedRating(1000, 1000, 0.5, games: 20), 1000);
  });

  test('the first ten games move faster', () {
    expect(updatedRating(1000, 1000, 1, games: 0), 1020);
    expect(updatedRating(1000, 1000, 1, games: 10), 1012);
  });

  test('beating a much stronger level pays more than a weaker one', () {
    final up = updatedRating(1000, 2000, 1, games: 20) - 1000;
    final down = updatedRating(1000, 600, 1, games: 20) - 1000;
    expect(up, greaterThan(down));
  });

  test('records survive encoding', () {
    const g = GameRecord(opponentElo: 1400, score: 0.5, ratingAfter: 1033);
    final back = GameRecord.decode(g.encode())!;
    expect(back.opponentElo, 1400);
    expect(back.score, 0.5);
    expect(back.ratingAfter, 1033);
    expect(back.result, 'D');
    expect(GameRecord.decode('junk'), isNull);
  });
}
