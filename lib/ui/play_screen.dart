import 'dart:math';

import 'package:flutter/material.dart';

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
import 'progress_store.dart';
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

  @override
  void initState() {
    super.initState();
    _board.addListener(_onBoardChanged);
  }

  @override
  void dispose() {
    _board.removeListener(_onBoardChanged);
    _board.dispose();
    super.dispose();
  }

  void _onBoardChanged() => setState(() {});

  Position get _pos => _board.position;
  String? get _draw => drawReason(_pos);
  bool get _over => _pos.legalMoves().isEmpty || _draw != null;
  bool get _myTurn => !_thinking && !_over && _pos.turn == _player;

  void _newGame({int? player}) {
    _game++;
    _player = player ?? _player;
    _thinking = false;
    _coach = null;
    _engineNote = null;
    _entries.clear();
    _showReview = false;
    _board.setPosition(Position.start());
    if (_player == black) _engineMove();
  }

  /// Lets the frame paint "thinking" before the synchronous search runs.
  Future<void> _engineMove() async {
    final game = _game;
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || game != _game) return;
    final pos = _pos;
    final move = chooseMove(pos, _level, widget.random);
    if (move == null) {
      setState(() => _thinking = false);
      return;
    }
    final name = san(pos, move);
    final why = explainVerified(pos, move);
    _engineNote = why.isEmpty ? 'I played $name.' : 'I played $name. ${why.first.text}';
    _thinking = false;
    _board.play(move);
  }

  Future<void> _onTap(int square) async {
    if (!_myTurn) return;
    final before = _pos;
    final move = _board.tap(square);
    if (move == null) return;
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
    if (_over) {
      setState(() => _thinking = false);
      return;
    }
    await _engineMove();
  }

  void _hint() {
    setState(() => _coach = analysePosition(_pos));
  }

  bool get _canUndo => !_thinking && _board.ply >= (_player == white ? 1 : 2);

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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SegmentedButton<Level>(
                  showSelectedIcon: false,
                  segments: [
                    for (final l in Level.values)
                      ButtonSegment(value: l, label: Text(l.label)),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
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
                child: BoardView(
                  position: _pos,
                  flipped: _player == black,
                  selected: _board.selected,
                  targets: _board.targets,
                  lastMove: _board.lastMoveSquares,
                  arrows: arrowsFit ? coach.arrows : const [],
                  onTap: _onTap,
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
              const SizedBox(height: 12),
              Text('${e.number} ${e.san}', style: theme.textTheme.titleSmall),
              Text(e.mistake!.text),
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
