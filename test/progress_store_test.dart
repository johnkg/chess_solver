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

  test('review cards, the rush best and saved games survive a reload', () async {
    final a = ProgressStore();
    await a.recordReview('fork-1', correct: false, today: 10);
    await a.recordReview('pin-2', correct: true, today: 10); // never missed: untracked
    expect(a.srsCards.keys, ['fork-1']);
    expect(a.dueForReview(10), isEmpty);
    expect(a.dueForReview(11), ['fork-1']);
    expect(await a.recordRush(7), isTrue);
    expect(await a.recordRush(5), isFalse);
    await a.saveGame('1. e4 e5 *');
    await a.saveGame('1. d4 d5 *');
    await a.saveGame('1. e4 e5 *'); // repeated: moves to the front, not duplicated
    expect(a.savedGames, ['1. e4 e5 *', '1. d4 d5 *']);

    final b = ProgressStore();
    await b.load();
    expect(b.srsCards['fork-1']!.due, 11);
    expect(b.rushBest, 7);
    expect(b.savedGames.length, 2);

    // Graduating all the way counts as learned and drops the card.
    var day = 11;
    for (var i = 0; i < 5; i++) {
      await b.recordReview('fork-1', correct: true, today: day);
      day += 40;
    }
    expect(b.srsCards, isEmpty);
    expect(b.puzzlesLearned, 1);

    await b.reset();
    expect(b.rushBest, 0);
    expect(b.savedGames, isEmpty);
    expect(b.puzzlesLearned, 0);
  });

  test('only the newest games are kept', () async {
    final a = ProgressStore();
    for (var i = 0; i < ProgressStore.savedGameLimit + 5; i++) {
      await a.saveGame('game $i');
    }
    expect(a.savedGames.length, ProgressStore.savedGameLimit);
    expect(a.savedGames.first, 'game ${ProgressStore.savedGameLimit + 4}');
  });
}
