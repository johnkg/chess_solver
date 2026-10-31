import 'package:flutter/material.dart';

import '../engine/mistakes.dart';
import '../engine/pgn.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_view.dart';
import 'controls.dart';
import 'labels.dart';
import 'layout.dart';
import 'pgn_dialogs.dart';
import 'progress_store.dart';
import 'review_snapshot.dart';
import 'widgets.dart';

/// Steps through a game loaded from PGN: first/previous/next/last, a move
/// list to jump around, the best move on demand, and a review of one side's
/// mistakes.
class GameViewer extends StatefulWidget {
  const GameViewer({super.key, required this.game, this.progress});

  final PgnGame game;

  /// When given, a review can add the ideas you missed to your weak spots.
  final ProgressStore? progress;

  @override
  State<GameViewer> createState() => _GameViewerState();
}

class _GameViewerState extends State<GameViewer> {
  late final List<Position> _positions = widget.game.positions;
  late final List<String> _names = [
    for (var i = 0; i < widget.game.moves.length; i++) san(_positions[i], widget.game.moves[i]),
  ];

  /// Number of moves played on the board: 0 = start.
  int _ply = 0;
  bool _flipped = false;
  Analysis? _hint;

  /// The review of each side that was asked for (white, black).
  final Map<int, List<ReviewEntry>> _reviews = {};
  final Set<int> _tracked = {};
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Position get _pos => _positions[_ply];

  void _go(int ply) {
    setState(() {
      _ply = ply.clamp(0, widget.game.moves.length);
      _hint = null;
    });
  }

  void _showBest() {
    if (_pos.legalMoves().isEmpty) return;
    setState(() => _hint = analysePosition(_pos));
  }

  Future<void> _review(Set<int> sides) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      for (final side in sides) {
        _reviews.remove(side);
        _tracked.remove(side);
      }
    });
    final out = {for (final side in sides) side: <ReviewEntry>[]};
    for (var i = 0; i < widget.game.moves.length; i++) {
      final list = out[_positions[i].turn];
      if (list == null) continue;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final move = widget.game.moves[i];
      final mistake = explainMistake(_positions[i], move);
      list.add(reviewMove(_positions[i], move, ply: i, mistake: mistake));
    }
    setState(() {
      _reviews.addAll(out);
      _busy = false;
    });
  }

  /// Shows the board before the move at [ply] and scrolls back up to it.
  void _show(int ply) {
    _go(ply);
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Adds the ideas this side missed to the weak-spot list, once.
  void _track(int side) {
    final progress = widget.progress;
    if (progress == null || !_tracked.add(side)) return;
    for (final e in _reviews[side] ?? const <ReviewEntry>[]) {
      final key = e.missedKey;
      if (key != null) progress.recordMiss(key);
    }
    setState(() {});
  }

  Widget _reviewCard(BuildContext context, int side) {
    final theme = Theme.of(context);
    final entries = _reviews[side]!;
    final mistakes = entries.where((e) => e.isMistake).toList();
    final trackable = mistakes.where((e) => e.missedKey != null).length;
    final accuracy = reviewAccuracy(entries);
    final who = '${colorName(side)} (${side == white ? widget.game.white : widget.game.black})';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review of $who', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (accuracy != null) Text('Accuracy $accuracy%', style: theme.textTheme.titleSmall),
            Text(reviewSummary(entries).replaceFirst('You played', '${colorName(side)} played')),
            if (widget.progress != null && trackable > 0) ...[
              gapSmall,
              OutlinedButton.icon(
                onPressed: _tracked.contains(side) ? null : () => _track(side),
                icon: Icon(_tracked.contains(side) ? Icons.check : Icons.fitness_center),
                label: Text(_tracked.contains(side)
                    ? 'Added to your weak spots'
                    : 'Practise these (${countOf(trackable, 'idea')})'),
              ),
            ],
            for (final e in mistakes) ...[
              const SizedBox(height: 16),
              ReviewSnapshot(entry: e, flipped: side == black),
              TextButton.icon(
                onPressed: () => _show(e.ply),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Show in the game'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final theme = Theme.of(context);
    final hint = _hint;
    final last = _ply == 0 ? null : game.moves[_ply - 1];
    final over = _ply == game.moves.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.white} – ${game.black}'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => setState(() => _flipped = !_flipped),
          ),
          IconButton(
            tooltip: 'Export PGN',
            icon: const Icon(Icons.ios_share),
            onPressed: () => showPgnExport(
              context,
              toPgn(game.moves, start: game.start, headers: game.headers, result: game.result),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: screenPadding,
          children: [
            BoardFrame(
              child: BoardView(
                position: _pos,
                flipped: _flipped,
                lastMove: last == null ? const {} : {last.from, last.to},
                arrows: hint?.arrows ?? const [],
              ),
            ),
            gapMedium,
            StepControls(ply: _ply, lastPly: game.moves.length, onGoTo: _go),
            gapSmall,
            Text(
              over ? 'End of game · ${game.result}' : 'Move ${_ply + 1} of ${game.moves.length}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            gapMedium,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _names.length; i++)
                  ChoiceChip(
                    label: Text(
                      '${_positions[i].turn == white ? '${_positions[i].fullmove}. ' : (i == 0 ? '${_positions[i].fullmove}... ' : '')}${_names[i]}',
                    ),
                    selected: _ply == i + 1,
                    onSelected: (_) => _go(i + 1),
                  ),
              ],
            ),
            gapMedium,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: over ? null : _showBest,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Best move here'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _review({white, black}),
                  child: const Text('Review both sides'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _review({white}),
                  child: const Text('Review White'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _review({black}),
                  child: const Text('Review Black'),
                ),
              ],
            ),
            if (hint != null) ...[
              gapMedium,
              CoachCard(text: hint.text),
            ],
            if (_busy) ...[
              gapMedium,
              const LinearProgressIndicator(),
            ],
            for (final side in [white, black])
              if (_reviews.containsKey(side)) ...[
                gapMedium,
                _reviewCard(context, side),
              ],
          ],
        ),
      ),
    );
  }
}
