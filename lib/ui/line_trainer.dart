import 'package:flutter/material.dart';

import '../engine/opening_line.dart';
import '../engine/piece.dart';
import '../lessons/lessons.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Id under which a finished opening line is saved in [ProgressStore].
String lineProgressId(Lesson lesson) => 'line-${lesson.id}';

/// Play your side of an opening line (or of a famous game) from memory. The other side answers with
/// the book move; a wrong move is taken back and counted.
class LineTrainer extends StatefulWidget {
  const LineTrainer({super.key, required this.lesson, this.progress, this.fromPly = 0});

  final Lesson lesson;

  /// Start from the position before this move of the line instead of the
  /// beginning. A run from the middle does not count as the line learned.
  final int fromPly;
  final ProgressStore? progress;

  @override
  State<LineTrainer> createState() => _LineTrainerState();
}

class _LineTrainerState extends State<LineTrainer> {
  late final OpeningLine _line = OpeningLine.fromSan(widget.lesson.line);
  final BoardController _board = BoardController();
  int _ply = 0; // moves of the line played so far
  int _mistakes = 0;
  int _hints = 0;
  bool _waiting = false;
  String? _feedback;
  CoachTone _tone = CoachTone.neutral;
  List<BoardArrow> _arrows = const [];
  int _run = 0;

  int get _me => widget.lesson.side == 'black' ? black : white;
  bool get _done => _ply >= _line.length;
  bool get _myTurn => !_waiting && !_done && _line.positions[_ply].turn == _me;

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

  void _restart() {
    _run++;
    _ply = widget.fromPly;
    _mistakes = 0;
    _hints = 0;
    _waiting = false;
    _arrows = const [];
    _feedback = widget.fromPly > 0
        ? 'The combination begins here. Find the ${_me == white ? 'White' : 'Black'} moves, or press Hint.'
        : 'Play the ${_me == white ? 'White' : 'Black'} moves of ${widget.lesson.title} from memory.';
    _tone = CoachTone.neutral;
    _board.setPosition(_line.positions[widget.fromPly]);
    _bookReply();
  }

  /// Plays the other side's book moves until it is your turn or the line ends.
  Future<void> _bookReply() async {
    final run = _run;
    while (!_done && _line.positions[_ply].turn != _me) {
      setState(() => _waiting = true);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted || run != _run) return;
      final note = widget.lesson.notes[_ply];
      _board.play(_line.moves[_ply]);
      _ply++;
      _feedback = '${_line.sans[_ply - 1]}${note.isEmpty ? '' : ': $note'}';
      _tone = CoachTone.neutral;
    }
    if (!mounted || run != _run) return;
    setState(() => _waiting = false);
    if (_done) _finish();
  }

  void _finish() {
    if (widget.fromPly == 0) widget.progress?.markSolved(lineProgressId(widget.lesson));
    setState(() {
      _tone = CoachTone.good;
      _feedback = _mistakes == 0
          ? (widget.fromPly > 0 ? 'Combination complete with no mistakes!' : 'Line complete with no mistakes!')
          : 'Line complete with $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}. Try again for a clean run.';
    });
  }

  Future<void> _onTap(int square) async {
    if (!_myTurn) return;
    final move = _board.tap(square);
    if (move == null) return;
    final want = _line.moves[_ply];
    if (move != want) {
      _board.undo();
      _mistakes++;
      setState(() {
        _tone = CoachTone.bad;
        _arrows = const [];
        _feedback = 'Not the book move. Think about what the line is trying to do, or press Hint.';
      });
      return;
    }
    final note = widget.lesson.notes[_ply];
    _ply++;
    _hints = 0;
    setState(() {
      _arrows = const [];
      _tone = CoachTone.good;
      _feedback = 'Correct: ${_line.sans[_ply - 1]}${note.isEmpty ? '' : '. $note'}';
    });
    if (_done) {
      _finish();
    } else {
      await _bookReply();
    }
  }

  void _hint() {
    _hints++;
    final want = _line.moves[_ply];
    if (_hints == 1) {
      final note = widget.lesson.notes[_ply];
      setState(() {
        _tone = CoachTone.neutral;
        _feedback = note.isEmpty
            ? (widget.lesson.level == 7
                ? 'Look for forcing moves: checks, captures and threats.'
                : 'Think about development and the center.')
            : 'Hint: $note';
      });
    } else {
      setState(() {
        _arrows = [BoardArrow(want.from, want.to, color: context.board.best)];
        _feedback = 'The book move is ${_line.sans[_ply]}.';
        _tone = CoachTone.neutral;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _done
        ? 'Done'
        : _waiting
            ? 'Opponent replies...'
            : 'Your move: ${_line.numberAt(_ply)}';
    return Scaffold(
      appBar: AppBar(title: Text('Train: ${widget.lesson.title}')),
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
              '$status · move ${(_ply ~/ 2) + 1} of ${(_line.length + 1) ~/ 2} · $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}',
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
                  label: Text(_done ? 'Again' : 'Restart'),
                ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              CoachCard(text: _feedback!, tone: _tone),
            ],
          ],
        ),
      ),
    );
  }
}
