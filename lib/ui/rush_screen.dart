import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/puzzle.dart';
import '../engine/rush.dart';
import '../puzzles/library.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'layout.dart';
import 'progress_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Puzzle Rush: solve as many one-move puzzles as you can in three minutes.
/// They get harder as you go, and three wrong moves end the run.
class RushScreen extends StatefulWidget {
  const RushScreen({
    super.key,
    required this.progress,
    this.puzzles,
    this.random,
    this.seconds = rushSeconds,
  });

  final ProgressStore progress;

  /// Puzzles to draw from; defaults to the library's one-move puzzles.
  final List<Puzzle>? puzzles;
  final Random? random;
  final int seconds;

  @override
  State<RushScreen> createState() => _RushScreenState();
}

class _RushScreenState extends State<RushScreen> {
  late final List<Puzzle> _pool = widget.puzzles ?? rushPool(puzzleLibrary);
  late final Random _rng = widget.random ?? Random();
  final BoardController _board = BoardController();
  final Set<String> _seen = {};
  Timer? _timer;
  Puzzle? _puzzle;
  int _left = 0;
  int _solved = 0;
  int _strikes = 0;
  bool _running = false;
  bool _newBest = false;
  String? _feedback;
  CoachTone _tone = CoachTone.neutral;

  bool get _over => !_running && _puzzle != null;

  @override
  void initState() {
    super.initState();
    _board.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _board.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _seen.clear();
    _solved = 0;
    _strikes = 0;
    _left = widget.seconds;
    _newBest = false;
    _running = true;
    _feedback = null;
    _tone = CoachTone.neutral;
    _show(nextRushPuzzle(_pool, 0, _seen, random: _rng));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _end();
    });
    setState(() {});
  }

  void _show(Puzzle? p) {
    _puzzle = p;
    if (p == null) {
      _end();
      return;
    }
    _seen.add(p.id);
    _board.setPosition(Position.fromFen(p.fen));
  }

  Future<void> _end() async {
    _timer?.cancel();
    if (!_running) return;
    _running = false;
    final best = await widget.progress.recordRush(_solved);
    if (!mounted) return;
    setState(() {
      _newBest = best && _solved > 0;
      _feedback = null;
    });
  }

  void _wrong(String text) {
    _strikes++;
    if (_strikes >= rushStrikes) {
      _end();
      return;
    }
    setState(() {
      _tone = CoachTone.bad;
      _feedback = text;
    });
  }

  void _onTap(int square) {
    if (!_running) return;
    final puzzle = _puzzle!;
    final start = Position.fromFen(puzzle.fen);
    final move = _board.tap(square);
    if (move == null) return;
    if (puzzle.solutions.contains(move.uci)) {
      _solved++;
      _tone = CoachTone.good;
      _feedback = 'Correct!';
      _show(nextRushPuzzle(_pool, _solved, _seen, random: _rng));
      setState(() {});
    } else {
      _board.setPosition(start);
      _wrong('Not that one. Strike $_strikes of $rushStrikes.');
    }
  }

  void _skip() {
    if (!_running) return;
    _strikes++;
    if (_strikes >= rushStrikes) {
      _end();
      return;
    }
    _tone = CoachTone.neutral;
    _feedback = 'Skipped. Strike $_strikes of $rushStrikes.';
    _show(nextRushPuzzle(_pool, _solved, _seen, random: _rng));
    setState(() {});
  }

  String get _clock {
    final m = _left ~/ 60;
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puzzle = _puzzle;
    final turn = puzzle == null ? white : Position.fromFen(puzzle.fen).turn;
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Rush')),
      body: SafeArea(
        child: ListView(
          padding: screenPadding,
          children: [
            if (puzzle == null) ...[
              gapSmall,
              CoachCard(
                title: 'Three minutes, three strikes',
                text: 'Find the winning move as fast as you can. Every puzzle has one move: '
                    'win material or give checkmate. They get harder every three you solve, '
                    'and three wrong moves end the run.\n\nYour best: ${widget.progress.rushBest}.',
              ),
              gapMedium,
              FilledButton.icon(
                onPressed: _pool.isEmpty ? null : _start,
                icon: const Icon(Icons.bolt),
                label: const Text('Start'),
              ),
            ] else ...[
              Row(
                children: [
                  Text(_clock, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: monoFamily)),
                  const Spacer(),
                  Text('Solved $_solved', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 16),
                  for (var i = 0; i < rushStrikes; i++)
                    Icon(
                      i < _strikes ? Icons.close : Icons.circle_outlined,
                      size: 20,
                      color: i < _strikes ? context.coach.bad : theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              gapTiny,
              if (_running) Text('${colorName(turn)} to move', style: theme.textTheme.bodyMedium),
              gapSmall,
              BoardFrame(
                child: BoardView(
                  position: _board.position,
                  flipped: turn == black,
                  selected: _board.selected,
                  targets: _board.targets,
                  onTap: _onTap,
                ),
              ),
              gapMedium,
              if (_running)
                OutlinedButton.icon(
                  onPressed: _skip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip (a strike)'),
                ),
              if (_over) ...[
                CoachCard(
                  title: _left <= 0 ? 'Time is up' : 'Out of strikes',
                  tone: _newBest ? CoachTone.good : CoachTone.neutral,
                  text: 'You solved $_solved.'
                      '${_newBest ? ' A new best!' : ' Your best is ${widget.progress.rushBest}.'}',
                ),
                gapMedium,
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.replay),
                  label: const Text('Play again'),
                ),
              ],
              if (_feedback != null && _running) ...[
                gapMedium,
                CoachCard(text: _feedback!, tone: _tone),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
