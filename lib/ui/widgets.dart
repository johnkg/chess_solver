import 'package:flutter/material.dart';

import 'theme.dart';

enum CoachTone { neutral, good, bad }

/// The sentence or two under the board that says why.
class CoachCard extends StatelessWidget {
  const CoachCard({super.key, required this.text, this.title, this.tone = CoachTone.neutral});

  final String text;
  final String? title;
  final CoachTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.coach;
    final scheme = Theme.of(context).colorScheme;
    final bg = switch (tone) {
      CoachTone.good => c.goodBg,
      CoachTone.bad => c.badBg,
      CoachTone.neutral => scheme.surfaceContainerHighest,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
          ],
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Dark (or amber) call-to-action block at the top of a tab.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    this.amber = false,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget action;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = amber ? scheme.primary : scheme.onSurface;
    final fg = amber ? scheme.onPrimary : scheme.surface;
    final theme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: theme.labelSmall?.copyWith(
              color: amber ? fg : scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: theme.titleLarge?.copyWith(color: fg)),
          const SizedBox(height: 4),
          Text(body, style: theme.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.85))),
          const SizedBox(height: 14),
          action,
        ],
      ),
    );
  }
}

/// Small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

/// Soft rounded row used for lessons, puzzles and weak spots.
class RowCard extends StatelessWidget {
  const RowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.titleMedium),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
