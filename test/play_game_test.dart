import 'dart:math';

import 'package:chess_solver/engine/clock.dart';
import 'package:chess_solver/engine/opponent.dart';
import 'package:chess_solver/engine/piece.dart';
import 'package:chess_solver/ui/play_game.dart';
import 'package:chess_solver/ui/progress_store.dart';
import 'package:chess_solver/ui/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PlayGame newGame({SideChoice side = SideChoice.white, SettingsStore? settings}) {
    final store = settings ?? SettingsStore()
      ..defaultLevel = Level.beginner
      ..defaultSide = side;
    final game = PlayGame(progress: ProgressStore(), settings: store, random: Random(3));
    addTearDown(game.dispose);
    return game;
  }

  int square(String name) => parseSquare(name);

  test('a new game starts with White to move and the human to play', () {
    final game = newGame();
    expect(game.player, white);
    expect(game.isMyTurn, isTrue);
    expect(game.status, 'Your move');
    expect(game.score, isNull);
    expect(game.isOver, isFalse);
  });

  test('playing Black makes the engine move first', () async {
    final game = newGame(side: SideChoice.black);
    expect(game.player, black);
    game.start();
    expect(game.thinking, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(game.board.ply, 1);
    expect(game.thinking, isFalse);
    expect(game.isMyTurn, isTrue);
  });

  test('a move gets a coach remark and an engine reply', () async {
    final game = newGame();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    expect(game.board.ply, 2, reason: 'your move and the reply');
    expect(game.entries, hasLength(1));
    expect(game.engineNote, startsWith('I played '));
    expect(game.isMyTurn, isTrue);
  });

  test('resigning ends the game as a loss and saves it', () async {
    final game = newGame();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    game.resign();
    expect(game.isOver, isTrue);
    expect(game.score, 0);
    expect(game.status, 'You resigned');
    expect(game.isMyTurn, isFalse);
    expect(game.progress.savedGames, hasLength(1));
    expect(game.progress.savedGames.single, contains('[Result "0-1"]'));
  });

  test('resigning twice or after the end changes nothing', () async {
    final game = newGame();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    game.resign();
    game.resign();
    expect(game.progress.savedGames, hasLength(1));
  });

  test('a hint makes the game practice and the second press shows the move', () {
    final game = newGame();
    expect(game.assisted, isFalse);
    game.hint();
    expect(game.assisted, isTrue);
    expect(game.isShowingFirstHint, isTrue);
    expect(game.coach!.text, startsWith('Hint: look at your'));
    game.hint();
    expect(game.isShowingFirstHint, isFalse);
    expect(game.coach!.move, isNotNull);
  });

  test('with stepwise hints off, one press shows the full answer', () {
    final settings = SettingsStore()
      ..defaultLevel = Level.beginner
      ..stepHints = false;
    final game = newGame(settings: settings);
    game.hint();
    expect(game.isShowingFirstHint, isFalse);
    expect(game.coach!.move, isNotNull);
  });

  test('taking back returns to your turn and marks the game unrated', () async {
    final game = newGame();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    expect(game.canUndo, isTrue);
    game.undo();
    expect(game.board.ply, 0);
    expect(game.assisted, isTrue);
    expect(game.entries, isEmpty);
    expect(game.isMyTurn, isTrue);
  });

  test('take-backs can be switched off in settings', () async {
    final settings = SettingsStore()
      ..defaultLevel = Level.beginner
      ..allowTakeBacks = false;
    final game = newGame(settings: settings);
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    expect(game.canUndo, isFalse);
  });

  test('a new game clears the old one', () async {
    final game = newGame();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    game.hint();
    game.newGame();
    expect(game.board.ply, 0);
    expect(game.entries, isEmpty);
    expect(game.coach, isNull);
    expect(game.assisted, isFalse);
    expect(game.isShowingFirstHint, isFalse);
  });

  test('startWith applies the chosen opponent, side and clock', () {
    final game = newGame();
    game.startWith(level: Level.expert, side: SideChoice.white, control: TimeControl.blitz5);
    expect(game.level, Level.expert);
    expect(game.clock, isNotNull);
    expect(game.control, TimeControl.blitz5);
  });

  test('a finished game is recorded once, in the rating when unassisted', () async {
    final game = newGame();
    final before = game.progress.rating;
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    game.resign();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(game.progress.rating, lessThan(before), reason: 'a loss lowers the rating');
    expect(game.ratingNote, startsWith('Rating '));
  });

  test('an assisted game is saved but not rated', () async {
    final game = newGame();
    final before = game.progress.rating;
    game.hint();
    await game.onTap(square('e2'));
    await game.onTap(square('e4'));
    game.resign();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(game.progress.rating, before);
    expect(game.ratingNote, startsWith('Practice game'));
  });

  test('listeners hear about every change', () async {
    final game = newGame();
    var notified = 0;
    game.addListener(() => notified++);
    game.hint();
    expect(notified, greaterThan(0));
  });
}
