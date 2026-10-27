import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/clock.dart';
import '../engine/explainer.dart';
import '../engine/opponent.dart';
import '../engine/mistakes.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'player_bar.dart';
import 'progress_store.dart';
import 'review_snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

/// Play a game against the engine. After each of your moves it says whether
/// the move was fine or a mistake, and why; it also says why it replied.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.progress, this.random});

  final ProgressStore progress;

  /// Fixed source of randomness for tests.
  final Random? random;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final BoardController _board = BoardController();
  Level _level = Level.casual;
  int _player = white;
  bool _thinking = false;
  Analysis? _coach;
  String? _engineNote;
  int _game = 0;
  final List<ReviewEntry> _entries = [];
  bool _showReview = false;
  TimeControl _control = TimeControl.off;
  ChessClock? _clock;
  Timer? _ticker;

  /// Side that ran out of time, or null.
  int? _flagged;

  @override
  void initState() {
    super.initState();
    _board.addListener(_onBoardChanged);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _board.removeListener(_onBoardChanged);
    _board.dispose();
    super.dispose();
  }

  void _onBoardChanged() => setState(() {});

  Position get _pos => _board.position;
  String? get _draw => drawReason(_pos);
  bool get _over => _pos.legalMoves().isEmpty || _draw != null || _flagged != null;
  bool get _myTurn => !_thinking && !_over && _pos.turn == _player;

  void _newGame({int? player}) {
    _game++;
    _player = player ?? _player;
    _thinking = false;
    _coach = null;
    _engineNote = null;
    _entries.clear();
    _showReview = false;
    _ticker?.cancel();
    _flagged = null;
    _clock = _control == TimeControl.off ? null : ChessClock(_control);
    if (_clock != null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    }
    _board.setPosition(Position.start());
    if (_player == black) _engineMove();
  }

  /// Updates the clock display and ends the game when someone runs out of time
  /// or the game ended another way.
  void _tick() {
    final clock = _clock;
    if (clock == null || !mounted) return;
    final now = DateTime.now();
    final side = clock.flagged(now);
    if (side != null) {
      clock.stop(now);
      _ticker?.cancel();
      setState(() => _flagged = side);
    } else if (_pos.legalMoves().isEmpty || _draw != null) {
      clock.stop(now);
      _ticker?.cancel();
      setState(() {});
    } else {
      setState(() {});
    }
  }

  /// Milliseconds the engine may spend: its level's time, but never more
  /// than a thirtieth of what is left on its clock.
  int _engineMillis() {
    final clock = _clock;
    if (clock == null) return _level.millis;
    final left = clock.remaining(1 - _player, DateTime.now());
    return min(_level.millis, max(150, left ~/ 30));
  }

  /// Lets the frame paint "thinking" before the synchronous search runs.
  Future<void> _engineMove() async {
    final game = _game;
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || game != _game) return;
    final pos = _pos;
    final move = chooseMove(pos, _level, widget.random, _engineMillis());
    if (move == null) {
      setState(() => _thinking = false);
      return;
    }
    if (_flagged != null) {
      _thinking = false;
      return;
    }
    final name = san(pos, move);
    final why = explainVerified(pos, move);
    _engineNote = why.isEmpty ? 'I played $name.' : 'I played $name. ${why.first.text}';
    _thinking = false;
    _board.play(move);
    _clock?.moved(1 - _player, DateTime.now());
  }

  Future<void> _onTap(int square) async {
    if (!_myTurn) return;
    final before = _pos;
    final move = _board.tap(square);
    if (move == null) return;
    _clock?.moved(_player, DateTime.now());
    _clock?.pause(DateTime.now()); // coach analysis is free
    final game = _game;
    setState(() {
      _thinking = true;
      _coach = null;
      _engineNote = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || game != _game) return;
    final mistake = explainMistake(before, move);
    final entry = reviewMove(before, move, ply: _board.ply - 1, mistake: mistake);
    _entries.add(entry);
    final key = entry.missedKey;
    if (key != null) widget.progress.recordMiss(key);
    _coach = critiqueWith(before, move, mistake);
    _clock?.resume(DateTime.now());
    if (_over) {
      setState(() => _thinking = false);
      return;
    }
    await _engineMove();
  }

  void _hint() {
    setState(() => _coach = analysePosition(_pos));
  }

  bool get _canUndo => !_thinking && _clock == null && _board.ply >= (_player == white ? 1 : 2);

  void _undo() {
    _board.undo();
    if (_pos.turn != _player && _board.canUndo) _board.undo();
    _entries.removeWhere((e) => e.ply >= _board.ply);
    setState(() {
      _coach = null;
      _engineNote = null;
    });
  }

  String get _status {
    if (_pos.isCheckmate) {
      return _pos.turn == _player ? 'Checkmate: you lose' : 'Checkmate: you win!';
    }
    if (_pos.isStalemate) return 'Stalemate: a draw';
    final f = _flagged;
    if (f != null) {
      return f == _player ? 'Time is up: you lose on time' : 'Opponent is out of time: you win!';
    }
    final d = _draw;
    if (d != null) return d;
    if (_thinking) return 'Thinking...';
    return 'Your move${_pos.inCheck ? ' (in check)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final coach = _coach;
    final showCoach = coach != null;
    final arrowsFit = coach != null && coach.fen == _pos.toFen();
    return Scaffold(
      appBar: AppBar(title: const Text('Play')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            LayoutBuilder(
              builder: (context, box) => DropdownMenu<Level>(
                width: box.maxWidth,
                initialSelection: _level,
                label: const Text('Opponent'),
                requestFocusOnTap: false,
                dropdownMenuEntries: [
                  for (final l in Level.values)
                    DropdownMenuEntry(value: l, label: l.title),
                ],
                onSelected: (l) {
                  if (l != null) setState(() => _level = l);
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownMenu<TimeControl>(
                  width: 170,
                  initialSelection: _control,
                  label: const Text('Clock'),
                  requestFocusOnTap: false,
                  dropdownMenuEntries: [
                    for (final c in TimeControl.values)
                      DropdownMenuEntry(value: c, label: c.label),
                  ],
                  onSelected: (c) {
                    if (c != null && c != _control) {
                      setState(() {
                        _control = c;
                        _newGame();
                      });
                    }
                  },
                ),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: white, label: Text('White')),
                    ButtonSegment(value: black, label: Text('Black')),
                  ],
                  selected: {_player},
                  onSelectionChanged: (s) =>
                      setState(() => _newGame(player: s.first)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _bar(opponent: true),
                    const SizedBox(height: 6),
                    BoardView(
                      position: _pos,
                      flipped: _player == black,
                      selected: _board.selected,
                      targets: _board.targets,
                      lastMove: _board.lastMoveSquares,
                      arrows: arrowsFit ? coach.arrows : const [],
                      onTap: _onTap,
                    ),
                    const SizedBox(height: 6),
                    _bar(opponent: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _pos.isCheckmate
                        ? (_pos.turn == _player ? context.coach.bad : context.coach.good)
                        : null,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _myTurn ? _hint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
                OutlinedButton.icon(
                  onPressed: _canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Take back'),
                ),
                OutlinedButton.icon(
                  onPressed: _entries.isEmpty
                      ? null
                      : () => setState(() => _showReview = !_showReview),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Game review'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_newGame),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('New game'),
                ),
              ],
            ),
            if (_engineNote != null || showCoach) ...[
              const SizedBox(height: 12),
              CoachCard(
                text: [
                  if (showCoach) coach.text,
                  ?_engineNote,
                ].join('\n\n'),
              ),
            ],
            if ((_showReview || _over) && _entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              _reviewCard(context),
            ],
          ],
        ),
      ),
    );
  }

  /// The strip above (opponent) or below (you) the board.
  Widget _bar({required bool opponent}) {
    final side = opponent ? 1 - _player : _player;
    final other = 1 - side;
    final mine = _board.capturedBy(side);
    final theirs = _board.capturedBy(other);
    int value(List<int> l) => l.fold(0, (sum, t) => sum + pieceValue(t));
    final clock = _clock;
    return PlayerBar(
      name: opponent ? _level.title : 'You',
      captured: mine,
      capturedColor: other,
      lead: value(mine) - value(theirs),
      clockMs: clock?.remaining(side, DateTime.now()),
      active: clock != null && clock.running == side && !_over,
    );
  }

  Widget _reviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final mistakes = _entries.where((e) => e.isMistake).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game review', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(reviewSummary(_entries)),
            for (final e in mistakes) ...[
              const SizedBox(height: 16),
              ReviewSnapshot(entry: e, flipped: _player == black),
            ],
            if (mistakes.any((e) => e.missedKey != null)) ...[
              const SizedBox(height: 12),
              const Text('Saved to your weak spots: see the Practice tab.'),
            ],
          ],
        ),
      ),
    );
  }
}
