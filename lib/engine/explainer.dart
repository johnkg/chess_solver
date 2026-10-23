import 'ideas/capture.dart';
import 'ideas/defender.dart';
import 'ideas/discovered.dart';
import 'ideas/fork.dart';
import 'ideas/lines.dart';
import 'ideas/mates.dart';
import 'ideas/positional.dart';
import 'insight.dart';
import 'move.dart';
import 'position.dart';
import 'search.dart';

/// Every idea the detectors see in [m], in teaching order: mates, material
/// wins, forks, discovered attacks, pins and skewers. If no tactic applies, a quiet-move reason
/// (castling, development, center) is returned instead.
///
/// Detectors only look at local patterns, so material claims here may be
/// wrong in the full position. Use [explainVerified] before telling a
/// learner that a move wins something.
List<Insight> explainMove(Position pos, Move m) {
  final next = pos.makeMove(m);
  final out = <Insight>[
    ...detectMate(pos, m, next),
    ...detectDoubleCheck(pos, m, next),
    ...detectCapture(pos, m, next),
    ...detectFork(pos, m, next),
    ...detectDiscovered(pos, m, next),
    ...detectRemoveDefender(pos, m, next),
    ...detectLines(pos, m, next),
  ];
  if (out.isEmpty) out.addAll(detectPositional(pos, m, next));
  return out;
}

/// Like [explainMove], but material claims (free piece, fork, skewer) are
/// kept only if a 2-ply material search confirms the claimed gain. Kept
/// claims are marked [Insight.verified].
List<Insight> explainVerified(Position pos, Move m) {
  final next = pos.makeMove(m);
  final out = <Insight>[];
  for (final ins in explainMove(pos, m)) {
    if (materialIdeas.contains(ins.idea) && ins.gain > 0) {
      if (pos.inCheck || materialMargin(pos, m) < ins.gain) continue;
      out.add(ins.asVerified());
    } else {
      out.add(ins);
    }
  }
  if (out.isEmpty) out.addAll(detectPositional(pos, m, next));
  return out;
}
