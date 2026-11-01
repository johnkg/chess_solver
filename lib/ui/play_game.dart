import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/clock.dart';
import '../engine/engine.dart';
import '../engine/explainer.dart';
import '../engine/game_result.dart';
import '../engine/mistakes.dart';
import '../engine/opponent.dart';
import '../engine/pgn.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'progress_store.dart';
import 'settings_store.dart';

/// How often the clock display is refreshed.
const Duration _clockTickInterval = Duration(milliseconds: 100);

/// Pause before a search starts so "thinking" can paint first.
const Duration _paintDelay = Duration(milliseconds: 60);

/// The engine never spends more than this fraction of its remaining clock on
/// one move (1 / this), and never less than [_minEngineMillis].
const int _clockShareDivisor = 30;
const int _minEngineMillis = 150;

/// A game shorter than this many plies is neither saved nor rated.
const int _minPliesToRecord = 2;

/// One game of the human against the engine: the board, whose turn it is, the
/// clock, the engine's replies, the coach's remarks, hints, take-backs,
/// resigning and recording the result. [PlayScreen] only shows it.
class PlayGame extends ChangeNotifier {
  PlayGame({required this.progress, required this.settings, Random? random})
      : _random = random,
        _rng = random ?? Random() {
    board.addListener(_onBoardChanged);
    level = settings.defaultLevel;
    sideChoice = settings.defaultSide;
    player = sideChoice.resolve(_rng);
  }

  final ProgressStore progress;

  /// Read for the coach, stepwise hints and take-backs; the screen keeps it
  /// pointing at the current settings.
  SettingsStore settings;

  /// Fixed source of randomness for tests; null in the app.
  final Random? _random;
  final Random _rng;

  final BoardController board = BoardController();
  late Level level;
  late SideChoice sideChoice;
  late int player;
  TimeControl control = TimeControl.off;
  ChessClock? clock;

  /// True while the engine searches or the coach analyses your move.
  bool thinking = false;

  /// What the coach says about your last move or hint, and why the engine
  /// replied as it did.
  Analysis? coach;
  String? engineNote;

  /// One entry per move of yours, for the game review.
  final List<ReviewEntry> entries = [];

  /// Side that ran out of time, or null.
  int? flagged;
  bool resigned = false;

  /// Hints or take-backs were used: the game is practice and not rated.
  bool assisted = false;
  String? ratingNote;

  /// Counts games so late answers from an abandoned game are ignored.
  int _gameId = 0;
  bool _recorded = false;
  bool _disposed = false;
  Searcher? _searcher;
  Timer? _ticker;

  // The current hint: the position it is for, how many times Hint was pressed
  // there, the full answer and the square the first hint points at.
  String? _hintFen;
  int _hintStage = 0;
  Analysis? _hintFull;
  int hintFrom = -1;

  Position get position => board.position;
  String? get drawText => drawReason(position, seen: board.seenKeys);
  bool get isOver =>
      position.legalMoves().isEmpty || drawText != null || flagged != null || resigned;
  bool get isMyTurn => !thinking && !isOver && position.turn == player;

  /// True while the first (piece-only) hint is showing for this position.
  bool get isShowingFirstHint => _hintStage == 1 && _hintFen == position.toFen();

  bool get canUndo =>
      settings.allowTakeBacks && !isOver && board.ply >= (player == white ? 1 : 2);

  /// 1, 0.5 or 0 for the player once the game is over, else null.
  double? get score => playerScore(
        pos: position,
        player: player,
        drawn: drawText != null,
        resigned: resigned,
        flagged: flagged,
      );

  String get status {
    if (position.isCheckmate) {
      return position.turn == player ? 'Checkmate: you lose' : 'Checkmate: you win!';
    }
    if (position.isStalemate) return 'Stalemate: a draw';
    if (resigned) return 'You resigned';
    final timedOut = flagged;
    if (timedOut != null) {
      return timedOut == player
          ? 'Time is up: you lose on time'
          : 'Opponent is out of time: you win!';
    }
    final draw = drawText;
    if (draw != null) return draw;
    if (thinking) return 'Thinking...';
    return 'Your move${position.inCheck ? ' (in check)' : ''}';
  }

  /// Starts the first game; the engine moves first when you play Black.
  void start() {
    if (player == black) _engineMove();
  }

  /// Starts a new game with the chosen opponent, side and clock.
  void startWith({required Level level, required SideChoice side, required TimeControl control}) {
    this.level = level;
    sideChoice = side;
    this.control = control;
    newGame(player: side.resolve(_rng));
  }

  void newGame({int? player}) {
    _gameId++;
    this.player = player ?? this.player;
    thinking = false;
    coach = null;
    engineNote = null;
    entries.clear();
    _searcher?.cancelled = true;
    _ticker?.cancel();
    flagged = null;
    resigned = false;
    assisted = false;
    _recorded = false;
    ratingNote = null;
    _hintFen = null;
    _hintStage = 0;
    clock = control == TimeControl.off ? null : ChessClock(control);
    if (clock != null) {
      _ticker = Timer.periodic(_clockTickInterval, (_) => _onClockTick());
    }
    board.setPosition(Position.start());
    if (this.player == black) _engineMove();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _searcher?.cancelled = true;
    _ticker?.cancel();
    board.removeListener(_onBoardChanged);
    board.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onBoardChanged() {
    _notify();
    _settle();
  }

  /// Updates the clock display and ends the game when someone runs out of time
  /// or the game ended another way.
  void _onClockTick() {
    final running = clock;
    if (running == null || _disposed) return;
    final now = DateTime.now();
    final outOfTime = running.flagged(now);
    if (outOfTime != null) {
      running.stop(now);
      _ticker?.cancel();
      _searcher?.cancelled = true;
      flagged = outOfTime;
      thinking = false;
      _notify();
      _settle();
    } else if (isOver) {
      running.stop(now);
      _ticker?.cancel();
      _notify();
    } else {
      _notify();
    }
  }

  /// Milliseconds the engine may spend: its level's time, but never more
  /// than its share of what is left on its clock.
  int _engineMillis() {
    final engineClock = clock;
    if (engineClock == null) return level.millis;
    final left = engineClock.remaining(1 - player, DateTime.now());
    return min(level.millis, max(_minEngineMillis, left ~/ _clockShareDivisor));
  }

  /// Lets the frame paint "thinking", then searches in slices so the clock
  /// keeps ticking and the buttons stay alive.
  Future<void> _engineMove() async {
    final gameId = _gameId;
    final searcher = Searcher();
    _searcher = searcher;
    thinking = true;
    _notify();
    await Future<void>.delayed(_paintDelay);
    if (_disposed || gameId != _gameId) return;
    final before = position;
    final move = await chooseMoveAsync(
      before,
      level,
      random: _random,
      maxMillis: _engineMillis(),
      searcher: searcher,
      history: board.seenKeys,
    );
    if (_disposed || gameId != _gameId) return;
    if (move == null || flagged != null) {
      thinking = false;
      _notify();
      return;
    }
    final name = san(before, move);
    final reasons = explainVerified(before, move);
    engineNote = !settings.coach
        ? null
        : reasons.isEmpty
            ? 'I played $name.'
            : 'I played $name. ${reasons.first.text}';
    thinking = false;
    board.play(move);
    clock?.moved(1 - player, DateTime.now());
  }

  /// A tap on [square]: selects or moves, then the coach judges the move and
  /// the engine replies.
  Future<void> onTap(int square) async {
    if (!isMyTurn) return;
    final before = position;
    final move = board.tap(square);
    if (move == null) return;
    clock?.moved(player, DateTime.now());
    clock?.pause(DateTime.now()); // coach analysis is free
    final gameId = _gameId;
    thinking = true;
    coach = null;
    engineNote = null;
    _notify();
    await Future<void>.delayed(_paintDelay);
    if (_disposed || gameId != _gameId) return;
    final mistake = explainMistake(before, move);
    final entry = reviewMove(before, move, ply: board.ply - 1, mistake: mistake);
    entries.add(entry);
    final missedKey = entry.missedKey;
    if (missedKey != null) progress.recordMiss(missedKey);
    coach = settings.coach ? critiqueWith(before, move, mistake) : null;
    clock?.resume(DateTime.now());
    if (isOver) {
      thinking = false;
      _notify();
      return;
    }
    await _engineMove();
  }

  /// First press points at the piece to move, second shows the move and why.
  void hint() {
    final fen = position.toFen();
    if (_hintFen != fen) {
      _hintFen = fen;
      _hintStage = 0;
      _hintFull = analysePosition(position);
    }
    final full = _hintFull!;
    final move = full.move;
    assisted = true;
    _hintStage = settings.stepHints ? _hintStage + 1 : 2;
    if (_hintStage == 1 && move != null) {
      hintFrom = move.from;
      final piece = pieceName(pieceType(position.squares[move.from]));
      coach = Analysis(
        fen: fen,
        text: 'Hint: look at your $piece on ${squareName(move.from)}. '
            'Press Hint again to see the move and why.',
      );
    } else {
      coach = full;
    }
    _notify();
  }

  /// Takes back your last move and the reply to it, even while the engine is
  /// thinking. The game then counts as practice, not rated. A running clock
  /// keeps its time but hands the turn back to you.
  void undo() {
    assisted = true;
    _gameId++;
    _searcher?.cancelled = true;
    thinking = false;
    board.undo();
    if (position.turn != player && board.canUndo) board.undo();
    entries.removeWhere((e) => e.ply >= board.ply);
    clock?.giveTurnTo(player, DateTime.now());
    coach = null;
    engineNote = null;
    _notify();
  }

  void resign() {
    if (isOver) return;
    _gameId++;
    _searcher?.cancelled = true;
    clock?.stop(DateTime.now());
    _ticker?.cancel();
    thinking = false;
    resigned = true;
    _notify();
    _settle();
  }

  /// Records the finished game once, in the rating unless hints or
  /// take-backs were used.
  void _settle() {
    final result = score;
    if (result == null || _recorded) return;
    _recorded = true;
    if (board.ply >= _minPliesToRecord) progress.saveGame(pgnText());
    if (assisted) {
      ratingNote = 'Practice game (hints or take-backs used): rating unchanged.';
      return;
    }
    if (board.ply < _minPliesToRecord) return;
    final before = progress.rating;
    final gameId = _gameId;
    progress.recordGame(level.elo, result).then((after) {
      if (_disposed || gameId != _gameId) return;
      ratingNote = ratingChangeNote(before, after);
      _notify();
    });
  }

  String pgnText() {
    const humanName = 'You';
    final opponentName = level.title;
    return toPgn(
      board.moves,
      result: pgnResultForScore(score, player),
      headers: {
        'Date': pgnDate(DateTime.now()),
        'White': player == white ? humanName : opponentName,
        'Black': player == white ? opponentName : humanName,
        'WhiteElo': '${player == white ? progress.rating : level.elo}',
        'BlackElo': '${player == white ? level.elo : progress.rating}',
      },
    );
  }
}
