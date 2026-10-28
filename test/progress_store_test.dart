import 'package:chess_solver/ui/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('misses are counted, relieved, saved and reloaded', () async {
    final a = ProgressStore();
    await a.recordMiss('fork');
    await a.recordMiss('fork');
    await a.recordMiss('mate');
    await a.relieve('mate');
    await a.relieve('pin'); // never missed: no-op
    expect(a.missed, {'fork': 2});

    final b = ProgressStore();
    await b.load();
    expect(b.missed, {'fork': 2});

    await b.reset();
    expect(b.missed, isEmpty);
  });

  test('rated games move the rating and survive a reload', () async {
    final a = ProgressStore();
    expect(a.rating, 1000);
    final r = await a.recordGame(1000, 1);
    expect(r, 1020);
    await a.recordGame(1400, 0);
    expect(a.games.length, 2);
    expect(a.peakRating, 1020);

    final b = ProgressStore();
    await b.load();
    expect(b.games.length, 2);
    expect(b.rating, a.rating);

    await b.reset();
    expect(b.rating, 1000);
    expect(b.games, isEmpty);
  });

  test('daily puzzle days are saved and reset', () async {
    final a = ProgressStore();
    await a.markDaily(20000);
    await a.markDaily(20000);
    await a.markDaily(20001);
    expect(a.dailyDays, {20000, 20001});

    final b = ProgressStore();
    await b.load();
    expect(b.dailyDays, {20000, 20001});
    await b.reset();
    expect(b.dailyDays, isEmpty);
  });
}
