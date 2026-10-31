import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/drill.dart';
import '../engine/engine.dart';
import '../engine/opponent.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/san.dart';
import '../engine/structure.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'layout.dart';
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Play a training position out against the engine. The goal is shown on top;
/// the drill ends when you reach it, fail it, or run out of moves.
class DrillScreen extends StatefulWidget {
  const DrillScreen({
    super.key,
    required this.drill,
    this.progress,
    this.random,
  });

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
  int _tries = 0;

  /// "Find" drills: the squares (or files) you have marked.
  final Set<int> _picked = {};
  bool _revealed = false;

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
    _tries = 0;
    _picked.clear();
    _revealed = false;
    _status = const DrillStatus(DrillState.running);
    _note = null;
    _board.setPosition(Position.fromFen(_drill.fen));
    final engineFirst =
        _pos.turn != _drill.side && _drill.goal != DrillGoal.find;
    if (engineFirst) _engineMove();
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

  Concept get _concept => Concept.values.byName(_drill.concept!);

  /// What a correct answer marks: files for file concepts, else squares.
  Set<int> get _expected => _concept.isFileConcept
      ? conceptFiles(_pos, _concept, _drill.subject)
      : conceptSquares(_pos, _concept, _drill.subject).toSet();

  Set<int> get _markedSquares => _concept.isFileConcept
      ? {
          for (final f in _picked)
            for (var r = 0; r < 8; r++) squareOf(r, f),
        }
      : _picked;

  void _mark(int square) {
    if (_status.over) return;
    final key = _concept.isFileConcept ? fileOf(square) : square;
    setState(() {
      _note = null;
      if (!_picked.remove(key)) _picked.add(key);
    });
  }

  void _check() {
    final want = _expected;
    final found = _picked.intersection(want);
    final extra = _picked.difference(want);
    final unit = _concept.isFileConcept ? 'files' : 'squares';
    if (found.length == want.length && extra.isEmpty) {
      widget.progress?.markSolved(_drill.id);
      setState(() {
        _status = const DrillStatus(DrillState.success, 'Exactly right.');
        _note = _drill.explain;
      });
      return;
    }
    _tries++;
    setState(() {
      _note =
          'You found ${found.length} of ${want.length}'
          '${extra.isEmpty ? '' : ' and marked ${extra.length} that do not count'}. '
          'Look again ($unit you mark turn blue), or press Hint.';
    });
  }

  Future<void> _onTap(int square) async {
    if (_drill.goal == DrillGoal.find) {
      _mark(square);
      return;
    }
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
    if (_drill.goal == DrillGoal.find) {
      if (_hints == 1) {
        setState(() => _note = _drill.hint);
      } else {
        setState(() {
          _picked
            ..clear()
            ..addAll(_expected);
          _revealed = true;
          _status = const DrillStatus(DrillState.failure, 'Answer shown.');
          _note = _drill.explain;
        });
      }
      return;
    }
    if (_hints == 1 || _pos.legalMoves().isEmpty) {
      setState(() => _note = _drill.hint);
      return;
    }
    final a = analysePosition(_pos);
    final m = a.move;
    setState(
      () => _note = m == null
          ? _drill.hint
          : 'Try ${san(_pos, m)}. ${_drill.hint}',
    );
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
        : _drill.goal == DrillGoal.find
        ? 'Tap to mark, tap again to unmark${_tries == 0 ? '' : ' · $_tries wrong'}'
        : 'Your move · ${_userMoves + 1} of ${_drill.maxMoves}';
    return Scaffold(
      appBar: AppBar(title: Text(_drill.title)),
      body: SafeArea(
        child: ListView(
          padding: screenPadding,
          children: [
            CoachCard(
              title: _drill.task,
              text: _drill.goal == DrillGoal.find
                  ? 'Look at the ${colorName(_drill.subject)} pieces.'
                  : 'You play ${colorName(_drill.side)} against ${_drill.engineLevel.title}.',
            ),
            gapMedium,
            BoardFrame(
              child: BoardView(
                position: _pos,
                flipped: _drill.side == black,
                selected: _board.selected,
                targets: _board.targets,
                highlights: _drill.goal == DrillGoal.find
                    ? _markedSquares
                    : const {},
                lastMove: _board.lastMoveSquares,
                onTap: _onTap,
              ),
            ),
            gapMedium,
            Text(
              turnLine,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: over
                    ? (good ? context.coach.good : context.coach.bad)
                    : null,
              ),
            ),
            gapSmall,
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
                if (_drill.goal == DrillGoal.find)
                  FilledButton.icon(
                    onPressed: over || _picked.isEmpty ? null : _check,
                    icon: const Icon(Icons.check),
                    label: const Text('Check'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(_start),
                  icon: const Icon(Icons.replay),
                  label: Text(over ? 'Try again' : 'Restart'),
                ),
              ],
            ),
            if (_note != null) ...[
              gapMedium,
              CoachCard(text: _note!),
            ],
            if (over) ...[
              gapMedium,
              CoachCard(
                tone: good ? CoachTone.good : CoachTone.bad,
                text: good
                    ? _drill.goal == DrillGoal.find
                          ? 'Well done: this drill is saved as solved.'
                          : '${_status.message} Well done: this drill is saved as solved.'
                    : _revealed
                    ? 'The marked ${_concept.isFileConcept ? 'files' : 'squares'} are the answer. Try again to practise it.'
                    : '${_status.message} Press Try again.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
