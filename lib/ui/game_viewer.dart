import 'package:flutter/material.dart';

import '../engine/mistakes.dart';
import '../engine/pgn.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import '../engine/san.dart';
import 'analysis.dart';
import 'board_view.dart';
import 'pgn_dialogs.dart';
import 'review_snapshot.dart';
import 'widgets.dart';

/// Steps through a game loaded from PGN: first/previous/next/last, a move
/// list to jump around, the best move on demand, and a review of one side's
/// mistakes.
class GameViewer extends StatefulWidget {
  const GameViewer({super.key, required this.game});

  final PgnGame game;

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

  List<ReviewEntry>? _entries;
  int? _reviewing;
  bool _busy = false;

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

  Future<void> _review(int side) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _reviewing = side;
      _entries = null;
    });
    final out = <ReviewEntry>[];
    for (var i = 0; i < widget.game.moves.length; i++) {
      if (_positions[i].turn != side) continue;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final move = widget.game.moves[i];
      final mistake = explainMistake(_positions[i], move);
      out.add(reviewMove(_positions[i], move, ply: i, mistake: mistake));
    }
    setState(() {
      _entries = out;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final theme = Theme.of(context);
    final hint = _hint;
    final last = _ply == 0 ? null : game.moves[_ply - 1];
    final entries = _entries;
    final mistakes = entries?.where((e) => e.isMistake).toList() ?? const [];
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: BoardView(
                  position: _pos,
                  flipped: _flipped,
                  lastMove: last == null ? const {} : {last.from, last.to},
                  arrows: hint?.arrows ?? const [],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Start',
                  onPressed: _ply == 0 ? null : () => _go(0),
                  icon: const Icon(Icons.first_page),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Back',
                  onPressed: _ply == 0 ? null : () => _go(_ply - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Next',
                  onPressed: over ? null : () => _go(_ply + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'End',
                  onPressed: over ? null : () => _go(game.moves.length),
                  icon: const Icon(Icons.last_page),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              over ? 'End of game · ${game.result}' : 'Move ${_ply + 1} of ${game.moves.length}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
                  onPressed: _busy ? null : () => _review(white),
                  child: const Text('Review White'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _review(black),
                  child: const Text('Review Black'),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 12),
              CoachCard(text: hint.text),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (entries != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review of ${colorName(_reviewing ?? white)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(reviewSummary(entries).replaceFirst('You played', '${colorName(_reviewing ?? white)} played')),
                      for (final e in mistakes) ...[
                        const SizedBox(height: 16),
                        ReviewSnapshot(entry: e, flipped: _reviewing == black),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
