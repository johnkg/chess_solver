import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/clock.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/review.dart';
import 'board_view.dart';
import 'game_viewer.dart';
import 'layout.dart';
import 'new_game_sheet.dart';
import 'pgn_dialogs.dart';
import 'play_game.dart';
import 'player_bar.dart';
import 'progress_screen.dart';
import 'progress_store.dart';
import 'rating_card.dart';
import 'review_snapshot.dart';
import 'settings_screen.dart';
import 'settings_store.dart';
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
  PlayGame? _gameState;
  bool _showReview = false;

  PlayGame get _game => _gameState!;
  Position get _pos => _game.position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = SettingsScope.of(context);
    final existing = _gameState;
    if (existing != null) {
      existing.settings = settings;
      return;
    }
    // The first game starts from the defaults in Settings.
    final created = PlayGame(progress: widget.progress, settings: settings, random: widget.random);
    created.addListener(_onGameChanged);
    _gameState = created;
    if (created.player == black) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && created.board.ply == 0 && !created.thinking) created.start();
      });
    }
  }

  @override
  void dispose() {
    _gameState?.removeListener(_onGameChanged);
    _gameState?.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _confirmResign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        content: Text(_game.assisted
            ? 'You used hints or take-backs, so this game is not rated.'
            : 'A resignation counts as a loss in your rating.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resign')),
        ],
      ),
    );
    if (confirmed == true && mounted) _game.resign();
  }

  void _exportPgn() => showPgnExport(context, _game.pgnText());

  Future<void> _importPgn() async {
    final game = await showPgnImport(context);
    if (game == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameViewer(game: game, progress: widget.progress)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coach = _game.coach;
    final showCoach = coach != null;
    final arrowsFit = coach != null && coach.fen == _pos.toFen();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play'),
        actions: [
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.add),
            onPressed: _openNewGame,
          ),
          ProgressButton(progress: widget.progress),
          SettingsButton(progress: widget.progress),
          PopupMenuButton<String>(
            tooltip: 'Game file',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => v == 'export' ? _exportPgn() : _importPgn(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                enabled: _game.board.ply > 0,
                child: const Text('Export PGN'),
              ),
              const PopupMenuItem(value: 'import', child: Text('Import PGN')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: screenPadding,
          children: [
            RatingCard(progress: widget.progress),
            gapMedium,
            _opponentRow(),
            gapMedium,
            BoardFrame(
              child: Column(
                children: [
                  _bar(opponent: true),
                  const SizedBox(height: 6),
                  BoardView(
                    position: _pos,
                    flipped: _game.player == black,
                    selected: _game.board.selected,
                    targets: _game.board.targets,
                    lastMove: _game.board.lastMoveSquares,
                    highlights: _game.isShowingFirstHint ? {_game.hintFrom} : const {},
                    arrows: arrowsFit ? coach.arrows : const [],
                    onTap: _game.onTap,
                  ),
                  const SizedBox(height: 6),
                  _bar(opponent: false),
                ],
              ),
            ),
            gapMedium,
            Text(
              _game.status,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _pos.isCheckmate
                        ? (_pos.turn == _game.player ? context.coach.bad : context.coach.good)
                        : null,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_game.ratingNote != null) ...[
              gapTiny,
              Text(
                _game.ratingNote!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            gapSmall,
            Wrap(
              alignment: WrapAlignment.center,
              spacing: wrapSpacing,
              runSpacing: wrapSpacing,
              children: [
                FilledButton.icon(
                  onPressed: _game.isMyTurn ? _game.hint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_game.isShowingFirstHint ? 'Show move' : 'Hint'),
                ),
                OutlinedButton.icon(
                  onPressed: _game.canUndo ? _game.undo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Take back'),
                ),
                OutlinedButton.icon(
                  onPressed: _game.entries.isEmpty
                      ? null
                      : () => setState(() => _showReview = !_showReview),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Game review'),
                ),
                OutlinedButton.icon(
                  onPressed: !_game.isOver && _game.board.ply > 0 ? _confirmResign : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Resign'),
                ),
                OutlinedButton.icon(
                  onPressed: _game.newGame,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('New game'),
                ),
              ],
            ),
            if (_game.engineNote != null || showCoach) ...[
              gapMedium,
              CoachCard(
                text: [
                  if (showCoach) coach.text,
                  ?_game.engineNote,
                ].join('\n\n'),
              ),
            ],
            if ((_showReview || _game.isOver) && _game.entries.isNotEmpty) ...[
              gapMedium,
              _reviewCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openNewGame() async {
    final choice = await showNewGameSheet(
      context,
      level: _game.level,
      side: _game.sideChoice,
      control: _game.control,
    );
    if (choice == null || !mounted) return;
    _game.startWith(level: choice.level, side: choice.side, control: choice.control);
  }

  /// Who you play and how; tap to change it (this starts a new game).
  Widget _opponentRow() {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final side = _game.player == white ? 'White' : 'Black';
    final clock = _game.control == TimeControl.off ? '' : ' · ${_game.control.label}';
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openNewGame,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_game.level.label, style: theme.titleMedium),
                      Text(
                        'About ${_game.level.elo} · you are $side$clock',
                        style: theme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Chip(label: Text('Change')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The strip above (opponent) or below (you) the board.
  Widget _bar({required bool opponent}) {
    final side = opponent ? 1 - _game.player : _game.player;
    final other = 1 - side;
    final mine = _game.board.capturedBy(side);
    final theirs = _game.board.capturedBy(other);
    int value(List<int> l) => l.fold(0, (sum, t) => sum + pieceValue(t));
    final clock = _game.clock;
    return PlayerBar(
      name: opponent ? _game.level.title : 'You',
      captured: mine,
      capturedColor: other,
      lead: value(mine) - value(theirs),
      clockMs: clock?.remaining(side, DateTime.now()),
      active: clock != null && clock.running == side && !_game.isOver,
    );
  }

  Widget _reviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _game.entries;
    final mistakes = entries.where((e) => e.isMistake).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game review', style: theme.textTheme.titleMedium),
            gapTiny,
            Text(reviewSummary(entries)),
            for (final e in mistakes) ...[
              gapLarge,
              ReviewSnapshot(entry: e, flipped: _game.player == black),
            ],
            if (mistakes.any((e) => e.missedKey != null)) ...[
              gapMedium,
              const Text('Saved to your weak spots: see the Practice tab.'),
            ],
          ],
        ),
      ),
    );
  }
}
