import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import 'labels.dart';
import 'lesson_screen.dart';

/// Lessons grouped by curriculum level.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final levels = {for (final l in lessons) l.level}.toList()..sort();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Learn chess')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final level in levels) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(levelTitle(level), style: theme.textTheme.titleMedium),
              ),
              for (final lesson in lessons.where((l) => l.level == level))
                ListTile(
                  title: Text(lesson.title),
                  subtitle: Text(lesson.tagline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LessonScreen(lesson: lesson),
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
