import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import 'labels.dart';
import 'lesson_screen.dart';
import 'progress_store.dart';
import 'widgets.dart';

/// Lessons grouped by curriculum level.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key, this.progress});

  final ProgressStore? progress;

  void _open(BuildContext context, Lesson lesson) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LessonScreen(lesson: lesson, progress: progress)),
      );

  @override
  Widget build(BuildContext context) {
    final levels = {for (final l in lessons) l.level}.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Learn chess')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
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
              for (final lesson in lessons.where((l) => l.level == level))
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
