import 'package:flutter/material.dart';

import '../engine/opening_line.dart';
import '../engine/piece.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'line_trainer.dart';
import 'progress_store.dart';
import 'widgets.dart';

/// Steps through an opening line with a note for every move, and offers to
/// train it.
class LineViewer extends StatefulWidget {
  const LineViewer({super.key, required this.lesson, this.progress});

  final Lesson lesson;
  final ProgressStore? progress;

  @override
  State<LineViewer> createState() => _LineViewerState();
}

class _LineViewerState extends State<LineViewer> {
  late final OpeningLine _line = OpeningLine.fromSan(widget.lesson.line);
  int _ply = 0; // moves played on the board

  void _go(int ply) => setState(() => _ply = ply.clamp(0, _line.length));

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final last = _ply == 0 ? null : _line.moves[_ply - 1];
    final note = _ply == 0 ? null : lesson.notes[_ply - 1];
    final flipped = lesson.side == 'black';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: BoardView(
              position: _line.positions[_ply],
              flipped: flipped,
              lastMove: last == null ? const {} : {last.from, last.to},
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
            IconButton.filled(
              tooltip: 'Next move',
              onPressed: _ply == _line.length ? null : () => _go(_ply + 1),
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'End',
              onPressed: _ply == _line.length ? null : () => _go(_line.length),
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CoachCard(
          title: _ply == 0 ? 'The starting position' : '${_line.numberAt(_ply - 1)} ${_line.sans[_ply - 1]}',
          text: _ply == 0
              ? 'Press Next move to step through the line. You study the ${lesson.side} side.'
              : (note == null || note.isEmpty ? 'A natural move.' : note),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _line.length; i++)
              ChoiceChip(
                label: Text(
                  '${_line.positions[i].turn == white ? '${_line.positions[i].fullmove}. ' : ''}${_line.sans[i]}',
                ),
                selected: _ply == i + 1,
                onSelected: (_) => _go(i + 1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LineTrainer(lesson: lesson, progress: widget.progress),
            ),
          ),
          icon: const Icon(Icons.fitness_center),
          label: Text(
            widget.progress?.isSolved(lineProgressId(lesson)) == true
                ? 'Train this line again'
                : 'Train this line',
          ),
        ),
      ],
    );
  }
}
