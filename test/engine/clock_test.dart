import 'package:chess_solver/engine/clock.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('nothing runs before the first move, which costs no time', () {
    final c = ChessClock(TimeControl.blitz5);
    expect(c.running, isNull);
    expect(c.remaining(white, at(60000)), 300000);
    c.moved(white, at(60000));
    expect(c.running, black);
    expect(c.remaining(white, at(90000)), 300000);
    expect(c.remaining(black, at(70000)), 290000);
  });

  test('a move pays for the time used and adds the increment', () {
    final c = ChessClock(TimeControl.blitz3); // 3 min + 2 s
    c.moved(white, at(0));
    c.moved(black, at(10000)); // black used 10 s
    expect(c.remaining(black, at(10000)), 180000 - 10000 + 2000);
    expect(c.running, white);
  });

  test('a side runs out of time and the clock stops', () {
    final c = ChessClock(TimeControl.blitz5);
    c.moved(white, at(0));
    expect(c.flagged(at(299000)), isNull);
    expect(c.flagged(at(300000)), black);
    expect(c.remaining(black, at(999999)), 0);
    c.stop(at(100000));
    expect(c.flagged(at(999999)), isNull);
    expect(c.remaining(black, at(999999)), 200000);
  });

  test('pause freezes the running side without switching', () {
    final c = ChessClock(TimeControl.blitz5);
    c.moved(white, at(0));
    c.pause(at(5000));
    expect(c.running, black);
    expect(c.remaining(black, at(60000)), 295000);
    c.resume(at(60000));
    expect(c.remaining(black, at(65000)), 290000);
  });

  test('formatClock', () {
    expect(formatClock(247000), '4:07');
    expect(formatClock(600000), '10:00');
    expect(formatClock(9400), '0:09.4');
    expect(formatClock(0), '0:00.0');
  });
}
