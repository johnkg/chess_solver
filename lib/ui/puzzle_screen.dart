import 'package:flutter/material.dart';

import '../engine/daily.dart' show dayNumber;
import '../engine/mate_line.dart';
import '../engine/mistakes.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/puzzle.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import '../engine/search.dart' show mateIn;
import '../engine/weakspots.dart';
import '../puzzles/library.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'labels.dart';
import 'layout.dart';
import 'progress_store.dart';
import 'settings_store.dart';
import 'widgets.dart';

/// Solve one puzzle: tap a piece, tap its destination. A wrong move is
/// explained and taken back; hints get more specific each time.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.puzzle,
    required this.progress,
    this.weakMode = false,
    this.seen = const {},
    this.dailyDay,
    this.nextPuzzle,
    this.nextLabel = 'Next puzzle',
    this.today,
  });

  final Puzzle puzzle;
  final ProgressStore progress;

  /// Launched from "Practice weak spots": offers the next one when solved.
  final bool weakMode;

  /// Puzzle ids already shown in this weak-spot drill.
  final Set<String> seen;

  /// Set when this is the daily puzzle of that day (see `dayNumber`).
  final int? dailyDay;

  /// Offers a "next" button once solved: gives the puzzle to go to, given the
  /// ids already shown in this run, or null when the run is over.
  final Puzzle? Function(Set<String> seen)? nextPuzzle;
  final String nextLabel;

  /// Day number for spaced review; defaults to today.
  final int? today;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late final Position _start;
  late final BoardController _board;
  bool _solved = false;
  bool _missed = false;
  bool _usedHint = false;
  int _hints = 0;

  /// Where the current step of the puzzle starts, and how many of your moves
  /// are left to mate. A mate in 3 plays on: you move, the opponent defends,
  /// and so on until checkmate.
  late Position _stepPos;
  late int _remaining;
  final List<String> _line = [];
  bool _busy = false;
  String? _feedback;
  List<BoardArrow> _arrows = const [];
  Set<int> _hintSquares = {};

  Puzzle get _puzzle => widget.puzzle;

  @override
  void initState() {
    super.initState();
    _start = Position.fromFen(_puzzle.fen);
    _stepPos = _start;
    _remaining = _puzzle.mateIn;
    _board = BoardController(_start);
    _board.addListener(_onChanged);
  }

  @override
  void dispose() {
    _board.removeListener(_onChanged);
    _board.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int get _today => widget.today ?? dayNumber(DateTime.now());

  bool get _firstStep => _line.isEmpty;

  bool _isCorrect(Move move) {
    if (_puzzle.mateIn == 0 || _firstStep) {
      return _puzzle.solutions.contains(move.uci);
    }
    return leadsToMate(_stepPos, move, _remaining);
  }

  Future<void> _onTap(int square) async {
    if (_solved || _busy) return;
    final move = _board.tap(square);
    if (move == null) return;
    final before = _stepPos;
    if (_isCorrect(move)) {
      _line.add(san(before, move));
      final after = before.makeMove(move);
      final done = _puzzle.mateIn == 0 || after.legalMoves().isEmpty;
      if (done) {
        _board.setPosition(after);
        widget.progress.markSolved(_puzzle.id);
        final day = widget.dailyDay;
        if (day != null) widget.progress.markDaily(day);
        if (!_missed && !_usedHint) {
          widget.progress.relieve(weakKey(_puzzle.idea));
          widget.progress.recordReview(_puzzle.id, correct: true, today: _today);
        }
        setState(() {
          _solved = true;
          _hintSquares = {};
          _arrows = const [];
          _feedback = _puzzle.mateIn == 0
              ? 'Correct: ${_line.last}.\n\n${_puzzle.text}'
              : 'Checkmate! ${_line.join(' ')}\n\n${_puzzle.text}';
        });
        return;
      }
      // Mate is still coming: the opponent defends, then you continue.
      setState(() {
        _busy = true;
        _hintSquares = {};
        _arrows = const [];
        _feedback = 'Correct: ${_line.last}. The opponent defends...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final reply = stubbornDefence(after, _remaining - 1);
      if (reply == null) return;
      _line.add(san(after, reply));
      _board.play(reply);
      _stepPos = after.makeMove(reply);
      _remaining--;
      _hints = 0;
      setState(() {
        _busy = false;
        _feedback = 'The opponent played ${_line.last}. '
            'Keep going: mate in $_remaining.';
      });
      return;
    }
    if (!_missed) {
      _missed = true;
      widget.progress.recordMiss(weakKey(_puzzle.idea));
      widget.progress.recordReview(_puzzle.id, correct: false, today: _today);
    }
    final mistake = explainMistake(before, move);
    setState(() {
      _feedback = mistake == null
          ? '${san(before, move)} is playable, but it is not the winning move here. Try again.'
          : 'Not that one. ${mistake.text}';
      _arrows = const [];
      _hintSquares = {};
    });
    _board.setPosition(before);
  }

  Move? _solutionMove() {
    if (_puzzle.mateIn > 0 && !_firstStep) return mateIn(_stepPos, _remaining);
    for (final m in _stepPos.legalMoves()) {
      if (_puzzle.solutions.contains(m.uci)) return m;
    }
    return null;
  }

  void _hint() {
    final m = _solutionMove();
    if (m == null || _solved || _busy) return;
    setState(() {
      _usedHint = true;
      _hints = !SettingsScope.of(context).stepHints ? 3 : (_hints < 3 ? _hints + 1 : 3);
      switch (_hints) {
        case 1:
          _feedback = _puzzle.mateIn > 0
              ? 'Look for a forced checkmate in $_remaining.'
              : _puzzle.idea == null
                  ? 'There is a winning move here.'
                  : 'Look for: ${ideaLabel(_puzzle.idea!).toLowerCase()}.';
          _hintSquares = {};
        case 2:
          _feedback = 'Move the highlighted piece.';
          _hintSquares = {m.from};
        default:
          _feedback = 'Play ${san(_stepPos, m)}.';
          _hintSquares = {m.from, m.to};
          _arrows = [BoardArrow(m.from, m.to)];
      }
    });
  }

  Puzzle? _upcoming(Set<String> seen) {
    final custom = widget.nextPuzzle;
    if (custom != null) return custom(seen);
    if (!widget.weakMode) return null;
    return nextWeakPuzzle(
      puzzleLibrary,
      widget.progress.missed,
      widget.progress.solved,
      skipId: _puzzle.id,
      seen: seen,
    );
  }

  bool get _hasNext => widget.weakMode || widget.nextPuzzle != null;

  void _next() {
    final seen = {...widget.seen, _puzzle.id};
    final next = _upcoming(seen);
    final nav = Navigator.of(context);
    if (next == null) {
      nav.pop();
      return;
    }
    nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(
          puzzle: next,
          progress: widget.progress,
          weakMode: widget.weakMode,
          seen: seen,
          nextPuzzle: widget.nextPuzzle,
          nextLabel: widget.nextLabel,
          today: widget.today,
        ),
      ),
    );
  }

  void _retry() {
    _board.setPosition(_start);
    _stepPos = _start;
    _remaining = _puzzle.mateIn;
    _line.clear();
    setState(() {
      _solved = false;
      _missed = false;
      _usedHint = false;
      _busy = false;
      _hints = 0;
      _feedback = null;
      _arrows = const [];
      _hintSquares = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pos = _board.position;
    final flipped = _start.turn == black;
    return Scaffold(
      appBar: AppBar(
        title: Text(_puzzle.mateIn > 0 ? 'Mate in ${_puzzle.mateIn}' : 'Win material'),
      ),
      body: SafeArea(
        child: ListView(
          padding: screenPadding,
          children: [
            Text(
              '${colorName(_start.turn)} to move. Find the best move.',
              style: theme.textTheme.titleMedium,
            ),
            gapMedium,
            BoardFrame(
              child: BoardView(
                position: pos,
                flipped: flipped,
                selected: _board.selected,
                targets: _board.targets,
                highlights: _hintSquares,
                lastMove: _solved ? _board.lastMoveSquares : const {},
                arrows: _arrows,
                onTap: _onTap,
              ),
            ),
            gapMedium,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _solved ? null : _hint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hints == 0 ? 'Hint' : 'Hint ($_hints/3)'),
                ),
                if (_solved && _hasNext)
                  FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(widget.weakMode ? 'Next weak spot' : widget.nextLabel),
                  ),
                if (_solved)
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.replay),
                    label: const Text('Again'),
                  ),
              ],
            ),
            if (_feedback != null) ...[
              gapMedium,
              CoachCard(
                text: _feedback!,
                tone: _solved
                    ? CoachTone.good
                    : _feedback!.startsWith('Not that one') ||
                            _feedback!.contains('not the winning move')
                        ? CoachTone.bad
                        : CoachTone.neutral,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
