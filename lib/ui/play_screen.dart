import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/clock.dart';
import '../engine/engine.dart';
import '../engine/explainer.dart';
import '../engine/opponent.dart';
import '../engine/mistakes.dart';
import '../engine/pgn.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'game_viewer.dart';
import 'pgn_dialogs.dart';
import 'player_bar.dart';
import 'progress_store.dart';
import 'rating_card.dart';
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
  Searcher? _searcher;
  bool _resigned = false;

  /// Hints or take-backs were used: the game is practice and not rated.
  bool _assisted = false;
  bool _recorded = false;
  String? _ratingNote;

  /// Position the current hint is for, how many times Hint was pressed there,
  /// the full answer and the square the first hint points at.
  String? _hintFen;
  int _hintStage = 0;
  Analysis? _hintFull;
  int _hintFrom = -1;

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

  void _onBoardChanged() {
    setState(() {});
    _settle();
  }

  Position get _pos => _board.position;
  String? get _draw => drawReason(_pos);
  bool get _over =>
      _pos.legalMoves().isEmpty || _draw != null || _flagged != null || _resigned;
  bool get _myTurn => !_thinking && !_over && _pos.turn == _player;

  void _newGame({int? player}) {
    _game++;
    _player = player ?? _player;
    _thinking = false;
    _coach = null;
    _engineNote = null;
    _entries.clear();
    _showReview = false;
    _searcher?.cancelled = true;
    _ticker?.cancel();
    _flagged = null;
    _resigned = false;
    _assisted = false;
    _recorded = false;
    _ratingNote = null;
    _hintFen = null;
    _hintStage = 0;
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
      _searcher?.cancelled = true;
      setState(() {
        _flagged = side;
        _thinking = false;
      });
      _settle();
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

  /// Lets the frame paint "thinking", then searches in slices so the clock
  /// keeps ticking and the buttons stay alive.
  Future<void> _engineMove() async {
    final game = _game;
    final searcher = Searcher();
    _searcher = searcher;
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || game != _game) return;
    final pos = _pos;
    final move = await chooseMoveAsync(
      pos,
      _level,
      random: widget.random,
      maxMillis: _engineMillis(),
      searcher: searcher,
    );
    if (!mounted || game != _game) return;
    if (move == null || _flagged != null) {
      setState(() => _thinking = false);
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

  /// First press points at the piece to move, second shows the move and why.
  void _hint() {
    final fen = _pos.toFen();
    if (_hintFen != fen) {
      _hintFen = fen;
      _hintStage = 0;
      _hintFull = analysePosition(_pos);
    }
    final full = _hintFull!;
    final move = full.move;
    _assisted = true;
    _hintStage++;
    if (_hintStage == 1 && move != null) {
      _hintFrom = move.from;
      final piece = pieceName(pieceType(_pos.squares[move.from]));
      setState(() {
        _coach = Analysis(
          fen: fen,
          text: 'Hint: look at your $piece on ${squareName(move.from)}. '
              'Press Hint again to see the move and why.',
        );
      });
    } else {
      setState(() => _coach = full);
    }
  }

  bool get _canUndo => !_over && _board.ply >= (_player == white ? 1 : 2);

  /// Takes back your last move and the reply to it, even while the engine is
  /// thinking. The game then counts as practice, not rated. A running clock
  /// keeps its time but hands the turn back to you.
  void _undo() {
    _assisted = true;
    _game++;
    _searcher?.cancelled = true;
    _thinking = false;
    _board.undo();
    if (_pos.turn != _player && _board.canUndo) _board.undo();
    _entries.removeWhere((e) => e.ply >= _board.ply);
    _clock?.giveTurnTo(_player, DateTime.now());
    setState(() {
      _coach = null;
      _engineNote = null;
    });
  }

  Future<void> _resign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        content: Text(_assisted
            ? 'You used hints or take-backs, so this game is not rated.'
            : 'A resignation counts as a loss in your rating.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resign')),
        ],
      ),
    );
    if (ok != true || !mounted || _over) return;
    _game++;
    _searcher?.cancelled = true;
    _clock?.stop(DateTime.now());
    _ticker?.cancel();
    setState(() {
      _thinking = false;
      _resigned = true;
    });
    _settle();
  }

  /// 1, 0.5 or 0 for the player once the game is over, else null.
  double? get _score {
    if (!_over) return null;
    if (_resigned) return 0;
    final f = _flagged;
    if (f != null) return f == _player ? 0 : 1;
    if (_pos.isCheckmate) return _pos.turn == _player ? 0 : 1;
    return 0.5;
  }

  /// Records the finished game once, in the rating unless hints or
  /// take-backs were used.
  void _settle() {
    final score = _score;
    if (score == null || _recorded) return;
    _recorded = true;
    if (_assisted) {
      _ratingNote = 'Practice game (hints or take-backs used): rating unchanged.';
      return;
    }
    if (_board.ply < 2) return;
    final before = widget.progress.rating;
    final game = _game;
    widget.progress.recordGame(_level.elo, score).then((after) {
      if (!mounted || game != _game) return;
      final d = after - before;
      setState(() => _ratingNote = 'Rating $after (${d >= 0 ? '+' : ''}$d).');
    });
  }

  String get _pgnResult {
    final s = _score;
    if (s == null) return '*';
    if (s == 0.5) return '1/2-1/2';
    return (s == 1) == (_player == white) ? '1-0' : '0-1';
  }

  void _exportPgn() {
    final now = DateTime.now();
    final date = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    final me = 'You';
    final opp = _level.title;
    showPgnExport(
      context,
      toPgn(
        _board.moves,
        result: _pgnResult,
        headers: {
          'Date': date,
          'White': _player == white ? me : opp,
          'Black': _player == white ? opp : me,
          'WhiteElo': '${_player == white ? widget.progress.rating : _level.elo}',
          'BlackElo': '${_player == white ? _level.elo : widget.progress.rating}',
        },
      ),
    );
  }

  Future<void> _importPgn() async {
    final game = await showPgnImport(context);
    if (game == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameViewer(game: game)),
    );
  }

  String get _status {
    if (_pos.isCheckmate) {
      return _pos.turn == _player ? 'Checkmate: you lose' : 'Checkmate: you win!';
    }
    if (_pos.isStalemate) return 'Stalemate: a draw';
    if (_resigned) return 'You resigned';
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
      appBar: AppBar(
        title: const Text('Play'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Game file',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => v == 'export' ? _exportPgn() : _importPgn(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                enabled: _board.ply > 0,
                child: const Text('Export PGN'),
              ),
              const PopupMenuItem(value: 'import', child: Text('Import PGN')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            RatingCard(progress: widget.progress),
            const SizedBox(height: 12),
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
                      highlights: _hintStage == 1 && _hintFen == _pos.toFen()
                          ? {_hintFrom}
                          : const {},
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
            if (_ratingNote != null) ...[
              const SizedBox(height: 4),
              Text(
                _ratingNote!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _myTurn ? _hint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(
                    _hintStage == 1 && _hintFen == _pos.toFen() ? 'Show move' : 'Hint',
                  ),
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
                  onPressed: !_over && _board.ply > 0 ? _resign : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Resign'),
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
