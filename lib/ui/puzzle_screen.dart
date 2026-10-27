import 'package:flutter/material.dart';

import '../engine/mistakes.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import '../engine/weakspots.dart';
import '../puzzles/library.dart';
import '../engine/puzzle.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'labels.dart';
import 'progress_store.dart';
import 'widgets.dart';

/// Solve one puzzle: tap a piece, tap its destination. A wrong move is
/// explained and taken back; hints get more specific each time.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.puzzle,
    required this.progress,
    this.weakMode = false,
  });

  final Puzzle puzzle;
  final ProgressStore progress;

  /// Launched from "Practice weak spots": offers the next one when solved.
  final bool weakMode;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late final Position _start;
  late final BoardController _board;
  bool _solved = false;
  bool _missed = false;
  int _hints = 0;
  String? _feedback;
  List<BoardArrow> _arrows = const [];
  Set<int> _hintSquares = {};

  Puzzle get _puzzle => widget.puzzle;

  @override
  void initState() {
    super.initState();
    _start = Position.fromFen(_puzzle.fen);
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

  void _onTap(int square) {
    if (_solved) return;
    final move = _board.tap(square);
    if (move == null) return;
    if (_puzzle.solutions.contains(move.uci)) {
      _board.setPosition(_start.makeMove(move));
      widget.progress.markSolved(_puzzle.id);
      if (!_missed && _hints == 0) {
        widget.progress.relieve(weakKey(_puzzle.idea));
      }
      setState(() {
        _solved = true;
        _hintSquares = {};
        _arrows = const [];
        _feedback = 'Correct: ${san(_start, move)}.\n\n${_puzzle.text}';
      });
      return;
    }
    if (!_missed) {
      _missed = true;
      widget.progress.recordMiss(weakKey(_puzzle.idea));
    }
    final mistake = explainMistake(_start, move);
    setState(() {
      _feedback = mistake == null
          ? '${san(_start, move)} is playable, but it is not the winning move here. Try again.'
          : 'Not that one. ${mistake.text}';
      _arrows = const [];
      _hintSquares = {};
    });
    _board.setPosition(_start);
  }

  Move? _solutionMove() {
    for (final m in _start.legalMoves()) {
      if (_puzzle.solutions.contains(m.uci)) return m;
    }
    return null;
  }

  void _hint() {
    final m = _solutionMove();
    if (m == null || _solved) return;
    setState(() {
      _hints = _hints < 3 ? _hints + 1 : 3;
      switch (_hints) {
        case 1:
          _feedback = _puzzle.mateIn > 0
              ? 'Look for a forced checkmate in ${_puzzle.mateIn}.'
              : _puzzle.idea == null
                  ? 'There is a winning move here.'
                  : 'Look for: ${ideaLabel(_puzzle.idea!).toLowerCase()}.';
          _hintSquares = {};
        case 2:
          _feedback = 'Move the highlighted piece.';
          _hintSquares = {m.from};
        default:
          _feedback = 'Play ${san(_start, m)}.';
          _hintSquares = {m.from, m.to};
          _arrows = [BoardArrow(m.from, m.to)];
      }
    });
  }

  void _next() {
    final next = nextWeakPuzzle(
      puzzleLibrary,
      widget.progress.missed,
      widget.progress.solved,
      skipId: _puzzle.id,
    );
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
          weakMode: true,
        ),
      ),
    );
  }

  void _retry() {
    _board.setPosition(_start);
    setState(() {
      _solved = false;
      _missed = false;
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              '${colorName(_start.turn)} to move. Find the best move.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
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
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _solved ? null : _hint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_hints == 0 ? 'Hint' : 'Hint ($_hints/3)'),
                ),
                const SizedBox(width: 8),
                if (_solved && widget.weakMode)
                  FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next weak spot'),
                  ),
                if (_solved && widget.weakMode) const SizedBox(width: 8),
                if (_solved)
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.replay),
                    label: const Text('Again'),
                  ),
              ],
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
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
