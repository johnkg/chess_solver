import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/piece.dart';
import '../engine/repertoire.dart';
import '../lessons/lessons.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'line_trainer.dart' show lineProgressId;
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Id under which a finished variation of an opening is saved in
/// [ProgressStore].
String variationProgressId(Lesson lesson, int index) => 'rep-${lesson.id}-$index';

/// Train a whole opening, not just one line: you play your side, and the
/// other side chooses a different variation each time, favouring the ones you
/// have not finished yet. Every move you play must be in the repertoire.
class RepertoireTrainer extends StatefulWidget {
  const RepertoireTrainer({super.key, required this.lesson, this.progress, this.random});

  final Lesson lesson;
  final ProgressStore? progress;

  /// Source of the opponent's choices; tests fix it.
  final Random? random;

  @override
  State<RepertoireTrainer> createState() => _RepertoireTrainerState();
}

class _RepertoireTrainerState extends State<RepertoireTrainer> {
  late final Repertoire _rep = Repertoire.fromLines(
    [
      widget.lesson.line,
      for (final b in widget.lesson.branches) b.split(' '),
    ],
    [widget.lesson.title, ...widget.lesson.branchNames],
  );
  final BoardController _board = BoardController();
  late RepNode _node = _rep.root;
  late final Set<int> _done = {
    for (var i = 0; i < _rep.lineCount; i++)
      if (widget.progress?.isSolved(variationProgressId(widget.lesson, i)) ?? false) i,
  };
  int _mistakes = 0;
  int _hints = 0;
  bool _waiting = false;
  bool _finished = false;
  String? _feedback;
  CoachTone _tone = CoachTone.neutral;
  List<BoardArrow> _arrows = const [];
  int _run = 0;

  int get _me => widget.lesson.side == 'black' ? black : white;
  bool get _myTurn => !_waiting && !_finished && _node.after.turn == _me;

  @override
  void initState() {
    super.initState();
    _board.addListener(() => setState(() {}));
    _restart();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  String _lineName(int line) => line == 0 ? widget.lesson.title : widget.lesson.branchNames[line - 1];

  void _restart() {
    _run++;
    _node = _rep.root;
    _mistakes = 0;
    _hints = 0;
    _waiting = false;
    _finished = false;
    _arrows = const [];
    _tone = CoachTone.neutral;
    _feedback = 'Play the ${_me == white ? 'White' : 'Black'} moves of the ${widget.lesson.title}. '
        'The other side picks a variation, so be ready for any of them.';
    _board.setPosition(_rep.root.after);
    _bookReply();
  }

  Future<void> _bookReply() async {
    final run = _run;
    while (!_node.isLeaf && _node.after.turn != _me) {
      setState(() => _waiting = true);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted || run != _run) return;
      final child = _rep.pickReply(_node, _done, widget.random);
      _board.play(child.move!);
      _node = child;
      final note = child.lines.contains(0) ? widget.lesson.notes[child.depth - 1] : '';
      _tone = CoachTone.neutral;
      _feedback = [
        child.san,
        if (child.name != null) ' · ${child.name}',
        if (note.isNotEmpty) ': $note',
      ].join();
    }
    if (!mounted || run != _run) return;
    setState(() => _waiting = false);
    if (_node.isLeaf) _finish();
  }

  void _finish() {
    final line = _rep.lineOf(_node);
    _done.add(line);
    widget.progress?.markSolved(variationProgressId(widget.lesson, line));
    if (_done.length == _rep.lineCount) {
      widget.progress?.markSolved(lineProgressId(widget.lesson));
    }
    setState(() {
      _finished = true;
      _tone = CoachTone.good;
      final left = _rep.lineCount - _done.length;
      _feedback = '${_lineName(line)} complete'
          '${_mistakes == 0 ? ' with no mistakes' : ' with $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}'}. '
          '${left == 0 ? 'You have played every variation: the whole repertoire is learned!' : '$left more to go.'}';
    });
  }

  Future<void> _onTap(int square) async {
    if (!_myTurn) return;
    final move = _board.tap(square);
    if (move == null) return;
    RepNode? next;
    for (final c in _node.children) {
      if (c.move == move) next = c;
    }
    if (next == null) {
      _board.undo();
      _mistakes++;
      setState(() {
        _tone = CoachTone.bad;
        _arrows = const [];
        _feedback = 'That is not in this repertoire. Think about what the opening is trying to do, or press Hint.';
      });
      return;
    }
    _node = next;
    _hints = 0;
    final note = next.lines.contains(0) ? widget.lesson.notes[next.depth - 1] : '';
    setState(() {
      _arrows = const [];
      _tone = CoachTone.good;
      _feedback = 'Correct: ${next!.san}${note.isEmpty ? '' : '. $note'}';
    });
    if (_node.isLeaf) {
      _finish();
    } else {
      await _bookReply();
    }
  }

  RepNode _suggested() => _node.children.firstWhere(
        (c) => c.lines.any((l) => !_done.contains(l)),
        orElse: () => _node.children.first,
      );

  void _hint() {
    _hints++;
    final want = _suggested();
    if (_hints == 1) {
      final note = want.lines.contains(0) ? widget.lesson.notes[want.depth - 1] : '';
      setState(() {
        _tone = CoachTone.neutral;
        _feedback = note.isEmpty ? 'Think about development and the center.' : 'Hint: $note';
      });
    } else {
      setState(() {
        _arrows = [BoardArrow(want.move!.from, want.move!.to, color: context.board.best)];
        _feedback = 'A book move is ${want.san}.';
        _tone = CoachTone.neutral;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _finished
        ? 'Done'
        : _waiting
            ? 'Opponent replies...'
            : 'Your move';
    return Scaffold(
      appBar: AppBar(title: Text('Repertoire: ${widget.lesson.title}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: BoardView(
                  position: _board.position,
                  flipped: _me == black,
                  selected: _board.selected,
                  targets: _board.targets,
                  lastMove: _board.lastMoveSquares,
                  arrows: _arrows,
                  onTap: _onTap,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$status · ${_done.length} of ${_rep.lineCount} variations learned · $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
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
                  label: Text(_hints == 0 ? 'Hint' : 'Show move'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_restart),
                  icon: const Icon(Icons.replay),
                  label: Text(_finished ? 'Another variation' : 'Restart'),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              CoachCard(text: _feedback!, tone: _tone),
            ],
            const SizedBox(height: 16),
            Text('Variations', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (var i = 0; i < _rep.lineCount; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _done.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _done.contains(i) ? context.coach.good : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(i == 0 ? '${widget.lesson.title} (main line)' : _lineName(i)),
              ),
          ],
        ),
      ),
    );
  }
}
