import 'package:flutter/material.dart';

import '../engine/explainer.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/position.dart';
import '../engine/san.dart';
import '../lessons/drills.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'drill_screen.dart';
import 'line_viewer.dart';
import 'progress_store.dart';
import 'widgets.dart';

/// One lesson: an example board, the idea in plain words, and (for idea and
/// move lessons) a button that shows the point on the board.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, this.progress});

  final Lesson lesson;
  final ProgressStore? progress;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Position _start;
  late Position _pos;
  Set<int> _highlights = {};
  Set<int> _lastMove = {};
  List<BoardArrow> _arrows = [];
  String? _demo;
  bool _shown = false;

  Lesson get _lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    _start = Position.fromFen(_lesson.fen);
    _pos = _start;
    _reset();
  }

  void _reset() {
    _pos = _start;
    _lastMove = {};
    _arrows = [];
    _demo = null;
    _shown = false;
    _highlights = {
      if (_lesson.kind == LessonKind.moves) ...[
        if (_lesson.square != null) parseSquare(_lesson.square!),
        for (final t in _lesson.targets) parseSquare(t),
      ],
    };
  }

  Move? _lessonMove() {
    final uci = _lesson.move;
    if (uci == null) return null;
    for (final m in _start.legalMoves()) {
      if (m.uci == uci) return m;
    }
    return null;
  }

  void _show() {
    final m = _lessonMove();
    if (m == null) return;
    final text = StringBuffer(
      '${colorName(_start.turn)} plays ${san(_start, m)}.',
    );
    final highlights = <int>{};
    if (_lesson.kind == LessonKind.plan) {
      final note = _lesson.note;
      if (note != null) text.write('\n\n$note');
    } else if (_lesson.kind == LessonKind.concept) {
      // Handled by _showConcept.
    } else {
      for (final i in explainVerified(_start, m)) {
        text.write('\n\n${i.text}');
        highlights.addAll(i.squares);
      }
    }
    setState(() {
      _pos = _start.makeMove(m);
      _lastMove = {m.from, m.to};
      _highlights = highlights;
      _arrows = const [];
      _demo = text.toString();
      _shown = true;
    });
  }

  void _showConcept() {
    final note = _lesson.note;
    setState(() {
      _highlights = {for (final t in _lesson.targets) parseSquare(t)};
      _demo = note;
      _shown = true;
    });
  }

  String _statusLine() {
    switch (_lesson.status) {
      case 'check':
        return _pos.inCheck
            ? 'The ${colorName(_pos.turn).toLowerCase()} king is in check.'
            : '';
      case 'checkmate':
        return _pos.isCheckmate
            ? 'Checkmate: ${colorName(1 - _pos.turn)} wins.'
            : '';
      case 'stalemate':
        return _pos.isStalemate ? 'Stalemate: a draw.' : '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConcept = _lesson.kind == LessonKind.concept;
    final canShow =
        isConcept ||
        ((_lesson.kind == LessonKind.idea || _lesson.kind == LessonKind.plan) &&
            _lessonMove() != null);
    final drillId = _lesson.drill;
    final drill = drillId == null
        ? null
        : drills.where((d) => d.id == drillId).firstOrNull;
    final status = _lesson.kind == LessonKind.status ? _statusLine() : '';
    return Scaffold(
      appBar: AppBar(title: Text(_lesson.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(_lesson.tagline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_lesson.kind == LessonKind.line) ...[
              LineViewer(lesson: _lesson, progress: widget.progress),
              const SizedBox(height: 16),
              Text(_lesson.why, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              const SectionLabel('What to look for'),
              const SizedBox(height: 4),
              for (final s in _lesson.spot)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
            ] else ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: BoardView(
                    position: _pos,
                    highlights: _highlights,
                    lastMove: _lastMove,
                    arrows: _arrows,
                  ),
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ],
              const SizedBox(height: 12),
              if (canShow)
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _shown
                          ? null
                          : (isConcept ? _showConcept : _show),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Show me'),
                    ),
                    const SizedBox(width: 8),
                    if (_shown)
                      OutlinedButton.icon(
                        onPressed: () => setState(_reset),
                        icon: const Icon(Icons.replay),
                        label: const Text('Again'),
                      ),
                  ],
                ),
              if (_demo != null) CoachCard(text: _demo!, tone: CoachTone.good),
              if (drill != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DrillScreen(drill: drill, progress: widget.progress),
                    ),
                  ),
                  icon: const Icon(Icons.fitness_center),
                  label: Text('Practise: ${drill.title}'),
                ),
              ],
              const SizedBox(height: 8),
              Text(_lesson.why, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              const SectionLabel('What to look for'),
              const SizedBox(height: 4),
              for (final s in _lesson.spot)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
