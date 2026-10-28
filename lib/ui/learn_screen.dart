import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import 'labels.dart';
import 'lesson_screen.dart';
import 'progress_store.dart';
import 'widgets.dart';

/// Which lessons the Learn tab shows.
enum LearnFilter {
  all('All', null),
  basics('Basics', {1, 2, 3, 4}),
  openings('Openings', {8}),
  middlegame('Middlegame', {6}),
  endgames('Endgames', {5}),
  games('Games', {7});

  const LearnFilter(this.label, this.levels);

  final String label;

  /// Curriculum levels shown, or null for all of them.
  final Set<int>? levels;
}

/// Lessons grouped by curriculum level.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, this.progress});

  final ProgressStore? progress;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  LearnFilter _filter = LearnFilter.all;

  void _open(BuildContext context, Lesson lesson) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LessonScreen(lesson: lesson, progress: widget.progress),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final l in lessons)
        if (_filter.levels == null || _filter.levels!.contains(l.level)) l,
    ];
    final levels = {for (final l in shown) l.level}.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Learn chess')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in LearnFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_filter == LearnFilter.all)
              HeroCard(
                eyebrow: 'Start here',
                title: lessons.first.title,
                body: lessons.first.tagline,
                action: FilledButton(
                  onPressed: () => _open(context, lessons.first),
                  child: const Text('Open lesson'),
                ),
              ),
            for (final level in levels) ...[
              SectionLabel(levelTitle(level)),
              for (final lesson in shown.where((l) => l.level == level))
                RowCard(
                  title: lesson.title,
                  subtitle: lesson.tagline,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, lesson),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
