import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/drill.dart';
import '../engine/engine.dart';
import '../engine/opponent.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Play a training position out against the engine. The goal is shown on top;
/// the drill ends when you reach it, fail it, or run out of moves.
class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key, required this.drill, this.progress, this.random});

  final Drill drill;

  /// Where a success is saved; null when opened without progress tracking.
  final ProgressStore? progress;

  /// Fixed source of randomness for tests.
  final Random? random;

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  late final BoardController _board;
  Searcher? _searcher;
  int _run = 0;
  int _userMoves = 0;
  bool _thinking = false;
  DrillStatus _status = const DrillStatus(DrillState.running);
  String? _note;
  int _hints = 0;

  Drill get _drill => widget.drill;
  Position get _pos => _board.position;
  bool get _myTurn => !_thinking && !_status.over && _pos.turn == _drill.side;

  @override
  void initState() {
    super.initState();
    _board = BoardController(Position.fromFen(_drill.fen));
    _board.addListener(_onBoard);
    _start();
  }

  @override
  void dispose() {
    _searcher?.cancelled = true;
    _board.removeListener(_onBoard);
    _board.dispose();
    super.dispose();
  }

  void _onBoard() => setState(() {});

  void _start() {
    _run++;
    _searcher?.cancelled = true;
    _userMoves = 0;
    _thinking = false;
    _hints = 0;
    _status = const DrillStatus(DrillState.running);
    _note = null;
    _board.setPosition(Position.fromFen(_drill.fen));
    if (_pos.turn != _drill.side) _engineMove();
  }

  void _judge() {
    final s = drillStatus(_drill, _pos, _userMoves);
    if (s.state == DrillState.success && _status.state != DrillState.success) {
      widget.progress?.markSolved(_drill.id);
    }
    setState(() => _status = s);
  }

  Future<void> _engineMove() async {
    final run = _run;
    final searcher = Searcher();
    _searcher = searcher;
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || run != _run) return;
    final move = await chooseMoveAsync(
      _pos,
      _drill.engineLevel,
      random: widget.random,
      maxMillis: 600,
      searcher: searcher,
    );
    if (!mounted || run != _run) return;
    _thinking = false;
    if (move != null) _board.play(move);
    _judge();
  }

  Future<void> _onTap(int square) async {
    if (!_myTurn) return;
    final move = _board.tap(square);
    if (move == null) return;
    _userMoves++;
    _note = null;
    _judge();
    if (_status.over) return;
    await _engineMove();
  }

  void _hint() {
    _hints++;
    if (_hints == 1 || _pos.legalMoves().isEmpty) {
      setState(() => _note = _drill.hint);
      return;
    }
    final a = analysePosition(_pos);
    final m = a.move;
    setState(() => _note = m == null
        ? _drill.hint
        : 'Try ${san(_pos, m)}. ${_drill.hint}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = _status.over;
    final good = _status.state == DrillState.success;
    final turnLine = over
        ? _status.message
        : _thinking
            ? 'Thinking...'
            : 'Your move · ${_userMoves + 1} of ${_drill.maxMoves}';
    return Scaffold(
      appBar: AppBar(title: Text(_drill.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            CoachCard(
              title: _drill.task,
              text: 'You play ${colorName(_drill.side)} against ${_drill.engineLevel.title}.',
            ),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: BoardView(
                  position: _pos,
                  flipped: _drill.side == black,
                  selected: _board.selected,
                  targets: _board.targets,
                  lastMove: _board.lastMoveSquares,
                  onTap: _onTap,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              turnLine,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: over ? (good ? context.coach.good : context.coach.bad) : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: over ? null : _hint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hints == 0 ? 'Hint' : 'Another hint'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_start),
                  icon: const Icon(Icons.replay),
                  label: Text(over ? 'Try again' : 'Restart'),
                ),
              ],
            ),
            if (_note != null) ...[
              const SizedBox(height: 12),
              CoachCard(text: _note!),
            ],
            if (over) ...[
              const SizedBox(height: 12),
              CoachCard(
                tone: good ? CoachTone.good : CoachTone.bad,
                text: good
                    ? '${_status.message} Well done: this drill is saved as solved.'
                    : '${_status.message} Press Try again.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
