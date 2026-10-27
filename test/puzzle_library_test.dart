import 'package:chess_solver/engine/position.dart';
import 'package:chess_solver/engine/rater.dart';
import 'package:chess_solver/puzzles/library.dart';
import 'package:flutter_test/flutter_test.dart';

/// Re-rates every curated puzzle with the real engine, the way
/// sudoku-solver's library_soundness_test does. If you change the search,
/// eval, detectors or rater on purpose, regenerate the library with
/// tool/curate.py.
void main() {
  test('library is not empty and ids are unique', () {
    expect(puzzleLibrary, isNotEmpty);
    expect(puzzleLibrary.map((p) => p.id).toSet(), hasLength(puzzleLibrary.length));
  });

  test('library has no duplicate positions', () {
    final boards = puzzleLibrary.map((p) => p.fen.split(' ').first).toSet();
    expect(boards, hasLength(puzzleLibrary.length));
  });

  test('library is ordered easiest tier first', () {
    final tiers = puzzleLibrary.map((p) => p.tier).toList();
    expect(tiers, orderedEquals([...tiers]..sort()));
  });

  for (final p in puzzleLibrary) {
    test('${p.id} rates as stored', () {
      final pos = Position.fromFen(p.fen);
      final r = ratePuzzle(pos, maxMate: p.mateIn > 0 ? p.mateIn : 1);
      expect(r, isNotNull, reason: p.fen);
      expect(r!.solutions, p.solutions);
      expect(r.san, p.san);
      expect(r.idea, p.idea);
      expect(r.tier, p.tier);
      expect(r.mateIn, p.mateIn);
      // Puzzles from real games start with a "From X vs Y, place year." line.
      expect(p.text.endsWith(r.text), isTrue, reason: p.text);
      expect(p.text == r.text || p.text.startsWith('From '), isTrue);
    });

    test('${p.id} solutions are legal moves', () {
      final pos = Position.fromFen(p.fen);
      final legal = pos.legalMoves().map((m) => m.uci).toSet();
      expect(legal, containsAll(p.solutions));
    });
  }
}
