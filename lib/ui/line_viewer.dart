import 'package:flutter/material.dart';

import '../engine/opening_line.dart';
import '../engine/piece.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'controls.dart';
import 'layout.dart';
import 'line_trainer.dart';
import 'progress_store.dart';
import 'repertoire_trainer.dart';
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
        BoardFrame(
          child: BoardView(
            position: _line.positions[_ply],
            flipped: flipped,
            lastMove: last == null ? const {} : {last.from, last.to},
          ),
        ),
        gapMedium,
        StepControls(ply: _ply, lastPly: _line.length, onGoTo: _go),
        gapMedium,
        CoachCard(
          title: _ply == 0 ? 'The starting position' : '${_line.numberAt(_ply - 1)} ${_line.sans[_ply - 1]}',
          text: _ply == 0
              ? 'Press Next move to step through the line. You study the ${lesson.side} side.'
              : (note == null || note.isEmpty ? 'No comment on this move.' : note),
        ),
        gapMedium,
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
        gapMedium,
        if (lesson.branches.isNotEmpty) ...[
          Text('Variations', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(lesson.branchNames.join(' · ')),
          gapSmall,
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RepertoireTrainer(lesson: lesson, progress: widget.progress),
              ),
            ),
            icon: const Icon(Icons.account_tree_outlined),
            label: Text('Train all ${lesson.branches.length + 1} variations'),
          ),
          gapSmall,
        ],
        if (lesson.start != null) ...[
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LineTrainer(lesson: lesson, progress: widget.progress, fromPly: lesson.start!),
              ),
            ),
            icon: const Icon(Icons.bolt),
            label: const Text('Start at the combination'),
          ),
          gapSmall,
        ],
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
