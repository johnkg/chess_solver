import 'dart:math';

import 'move.dart';
import 'position.dart';
import 'san.dart';

/// One position in an opening tree: [san] is the move that led here.
class RepNode {
  RepNode._(this.san, this.move, this.before, this.after, this.depth);

  final String san;
  final Move? move;
  final Position before;
  final Position after;

  /// Plies played to get here (the root is 0).
  final int depth;

  final List<RepNode> children = [];

  /// Indexes of the lines that pass through this node.
  final Set<int> lines = {};

  /// Set on the first node a named line adds to the tree: the name of the
  /// variation that starts here.
  String? name;

  bool get isLeaf => children.isEmpty;
}

/// Several lines of one opening merged into a tree: the main line and its
/// branches. The player picks a side; the other side follows a branch.
class Repertoire {
  Repertoire._(this.root, this.lineCount);

  /// Builds the tree. Line 0 is the main line. A line that ends where another
  /// continues, or repeats one, is a [FormatException]; so is an illegal move.
  factory Repertoire.fromLines(
    List<List<String>> lines,
    List<String> names, {
    Position? start,
  }) {
    final first = start ?? Position.start();
    final root = RepNode._('', null, first, first, 0);
    for (var i = 0; i < lines.length; i++) {
      var node = root;
      var created = false;
      for (var k = 0; k < lines[i].length; k++) {
        final s = lines[i][k];
        RepNode? next;
        for (final c in node.children) {
          if (c.san == s) next = c;
        }
        if (next != null && next.isLeaf && k < lines[i].length - 1) {
          throw FormatException('Line ${i + 1} continues past the end of another line.');
        }
        if (next == null) {
          final m = moveFromSan(node.after, s);
          if (m == null) {
            throw FormatException('Line ${i + 1}: move $s is not legal after ${node.depth} plies.');
          }
          next = RepNode._(s, m, node.after, node.after.makeMove(m), node.depth + 1);
          if (!created && node.children.isNotEmpty) next.name = i < names.length ? names[i] : null;
          created = true;
          node.children.add(next);
        }
        next.lines.add(i);
        node = next;
      }
      if (!created) throw FormatException('Line ${i + 1} adds nothing new.');
      if (!node.isLeaf) throw FormatException('Line ${i + 1} stops in the middle of another line.');
    }
    return Repertoire._(root, lines.length);
  }

  final RepNode root;

  /// How many lines went in (the main line and its branches).
  final int lineCount;

  /// The line that ends at [leaf].
  int lineOf(RepNode leaf) => leaf.lines.first;

  /// The opponent's reply from [node]: a random child, favouring branches that
  /// lead to lines not in [done] yet.
  RepNode pickReply(RepNode node, Set<int> done, [Random? random]) {
    final rng = random ?? Random();
    final weights = [
      for (final c in node.children) c.lines.any((l) => !done.contains(l)) ? 4 : 1,
    ];
    var pick = rng.nextInt(weights.reduce((a, b) => a + b));
    for (var i = 0; i < weights.length; i++) {
      pick -= weights[i];
      if (pick < 0) return node.children[i];
    }
    return node.children.last;
  }
}
