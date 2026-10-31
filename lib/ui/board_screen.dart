import 'package:flutter/material.dart';

import '../engine/position.dart';
import 'analysis.dart';
import 'board_controller.dart';
import 'board_view.dart';
import 'labels.dart';
import 'progress_store.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Free play: move pieces, ask for the best move, or ask why your last move
/// was good or bad.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, this.progress});

  final ProgressStore? progress;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardController _board = BoardController();
  bool _flipped = false;
  Analysis? _analysis;

  @override
  void initState() {
    super.initState();
    _board.addListener(_onBoardChanged);
  }

  @override
  void dispose() {
    _board.removeListener(_onBoardChanged);
    _board.dispose();
    super.dispose();
  }

  void _onBoardChanged() => setState(() {});

  /// The analysis is only shown while it still describes the board.
  Analysis? get _current {
    final a = _analysis;
    return a != null && a.fen == _board.position.toFen() ? a : null;
  }

  bool get _gameOver => _board.position.legalMoves().isEmpty;

  void _suggest() {
    if (_gameOver) return;
    setState(() => _analysis = analysePosition(_board.position));
  }

  void _critique() {
    final before = _board.previous;
    final move = _board.lastMove;
    if (before == null || move == null) return;
    setState(() => _analysis = critiqueMove(before, move));
  }

  Future<void> _pasteFen() async {
    // No controller: disposing one right after pop would leave the closing
    // dialog's TextField listening to a dead controller.
    var text = '';
    final fen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste a FEN'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => text = v,
          decoration: const InputDecoration(hintText: 'rnbqkbnr/pppppppp/...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (fen == null || fen.trim().isEmpty) return;
    try {
      _board.setPosition(Position.fromFen(fen.trim()));
      setState(() => _analysis = null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That is not a valid FEN.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = _board.position;
    final analysis = _current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          SettingsButton(progress: widget.progress),
          IconButton(
            tooltip: 'Paste FEN',
            icon: const Icon(Icons.content_paste),
            onPressed: _pasteFen,
          ),
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => setState(() => _flipped = !_flipped),
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
                  position: pos,
                  flipped: _flipped,
                  selected: _board.selected,
                  targets: _board.targets,
                  lastMove: _board.lastMoveSquares,
                  arrows: analysis?.arrows ?? const [],
                  onTap: (sq) {
                    _board.tap(sq);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText(pos),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _gameOver ? null : _suggest,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Best move'),
                ),
                OutlinedButton.icon(
                  onPressed: _board.canUndo ? _critique : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Rate my last move'),
                ),
                OutlinedButton.icon(
                  onPressed: _board.canUndo ? _board.undo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _board.setPosition(Position.start());
                    setState(() => _analysis = null);
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
            if (analysis != null) ...[
              const SizedBox(height: 12),
              CoachCard(text: analysis.text),
            ],
          ],
        ),
      ),
    );
  }
}
