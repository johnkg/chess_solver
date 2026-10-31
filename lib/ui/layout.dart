import 'package:flutter/material.dart';

/// Widest the board grows on large screens.
const double boardMaxWidth = 520;

/// Padding of every scrolling screen body.
const EdgeInsets screenPadding = EdgeInsets.fromLTRB(16, 4, 16, 24);

/// Vertical space between stacked blocks, from tight to roomy.
const Widget gapSmall = SizedBox(height: 8);
const Widget gapMedium = SizedBox(height: 12);

/// Horizontal space between side-by-side buttons.
const Widget gapSmallHorizontal = SizedBox(width: 8);

/// Centers [child] and stops it growing past [boardMaxWidth]; every screen
/// that shows a board puts it in one.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: boardMaxWidth),
        child: child,
      ),
    );
  }
}
