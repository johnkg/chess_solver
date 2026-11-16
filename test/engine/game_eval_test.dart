import 'package:chess_solver/engine/game_eval.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/search.dart';
import 'package:flutter_test/flutter_test.dart';

int score(String fen) => whiteScore(Position.fromFen(fen));

void main() {
  group('whiteScore', () {
    test('the start is about level', () {
      expect(whiteScore(Position.start()).abs(), lessThan(100));
    });

    test('is from White\'s view whoever is to move', () {
      expect(score('4k3/8/8/8/8/8/8/3QK3 w - - 0 1'), greaterThan(500));
      expect(score('4k3/8/8/8/8/8/8/3QK3 b - - 0 1'), greaterThan(500));
      expect(score('3qk3/8/8/8/8/8/8/4K3 w - - 0 1'), lessThan(-500));
    });

    test('a finished mate and a mate to come', () {
      // Black is mated.
      expect(score('R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1'), mateScore);
      // White mates in one; Black mates in one.
      expect(scoreLabel(score('7k/6pp/8/8/8/8/8/R5K1 w - - 0 1')), 'M1');
      expect(scoreLabel(score('r5k1/8/8/8/8/8/6PP/7K b - - 0 1')), '-M1');
    });

    test('stalemate is level', () {
      expect(score('k7/2Q5/1K6/8/8/8/8/8 b - - 0 1'), 0);
    });
  });

  test('scoreLabel', () {
    expect(scoreLabel(130), '+1.3');
    expect(scoreLabel(-40), '-0.4');
    expect(scoreLabel(3), '0.0');
    expect(scoreLabel(mateScore), '#');
    expect(scoreLabel(-mateScore), '-#');
    expect(scoreLabel(mateScore - 3), 'M2');
    expect(movesToMate(250), isNull);
  });

  test('whiteShare is half at level, grows with the score, and is full at mate', () {
    expect(whiteShare(0), closeTo(0.5, 1e-9));
    expect(whiteShare(200), greaterThan(whiteShare(100)));
    expect(whiteShare(-200), lessThan(0.5));
    expect(whiteShare(mateScore - 5), 1);
    expect(whiteShare(-mateScore + 5), 0);
  });

  group('biggestSwings', () {
    test('finds the moves that cost their side, biggest first', () {
      // Move 0 (White) loses 400; move 3 (Black) loses 800; move 1 (Black) gains.
      expect(biggestSwings([0, -400, -900, -900, -100], white), [3, 0]);
    });

    test('knows who moved first', () {
      expect(biggestSwings([0, -400], white), [0]);
      expect(biggestSwings([0, -400], black), isEmpty);
      expect(biggestSwings([0, 400], black), [0]);
    });

    test('small changes are ignored and mates are capped', () {
      expect(biggestSwings([0, -100], white), isEmpty);
      // White throws away a mate (capped loss), then Black drops 3 pawns.
      expect(biggestSwings([mateScore - 1, 0, 300], white), [0, 1]);
    });
  });
}
