# Chess Technique Teacher: Plan

## Goal

Teach chess from scratch, and explain **why** a move is good. Not a black-box engine that prints "best move: Nf6". It names the idea (fork, pin, develop a piece, control the center), shows the pattern on the board, and says in plain words what the move achieves and what the alternative loses.

Also solves puzzles: mate-in-N and win-material tactics, with the same explanations.

Modeled on `johnkg/sudoku-solver` (technique ladder, Step with explanation, rater, hint ladder, lessons, daily puzzle). Same stack and layout.

## Stack

- **Flutter + Dart**, same as sudoku-solver. Runs on web (GitHub Pages), Android, iOS, macOS.
- Engine in `lib/engine/` is pure Dart, no Flutter imports, runs offline on device.
- `shared_preferences` for progress and saved games.
- CI: `.github/workflows/pages.yml` (analyze, test, build web, deploy), copied from sudoku-solver.
- **Not Stockfish.** It would need WASM on web (threads need COOP/COEP headers, which GitHub Pages cannot set) and FFI/native builds per platform, plus GPL. It also gives numbers, not reasons. Optional later: Stockfish as a checker in tests only.

## Core design idea

Same as sudoku: a **technique-based explainer**, search is only the safety net.

1. Keep a `Position` (board, side to move, castling, en passant, clocks).
2. For a position, run **idea detectors** from simple to complex. Each returns an `Insight` for a move.
3. An `Insight` says: which idea, which squares/pieces are involved, the concrete line, and a plain-language explanation filled with real square and piece names.
4. A small alpha-beta search (`search.dart`) verifies claims: mate-in-N exists, material really is won, the player's move really loses a piece. Search proves; detectors explain.
5. "Why is this move good" = best move from search + the simplest `Insight` that accounts for it + an eval-breakdown diff (material, center, development, king safety, activity, pawn structure).
6. "Why is my move bad" = the refutation line from search, explained by the same detectors from the opponent's side.

Puzzle difficulty = the hardest idea the solution needs (same rater idea as sudoku).

## Idea ladder (curriculum)

| Level | Topic | Ideas |
|-------|-------|-------|
| 1 Rules | How pieces move | Piece moves, capture, check, checkmate, stalemate, castling, en passant, promotion |
| 2 Basic mates | Finish the game | K+Q vs K, K+R vs K, back-rank mate, ladder mate |
| 3 Principles | Why moves are good | Material values, free pieces (hanging), trades, control the center, develop pieces, castle early, king safety |
| 4 Tactics | Win material or mate | Fork, pin, skewer, discovered attack, double check, removing the defender, deflection, mate in 1/2/3, smothered mate, Greek gift |
| 5 Endgames | Convert the advantage | Opposition, king+pawn (square, key squares), passed pawns, Lucena, Philidor |
| 6 Strategy (stretch) | Quiet moves | Pawn structure, outposts, open files, bad bishop, weak squares |

Each level builds on the one before: first "how things move", then "what is safe", then "how to win something", then "how to keep winning".

**Honest limit:** tactics explain precisely. Quiet positional moves explain only roughly ("improves piece activity, controls d5"). Level 6 is a stretch for that reason.

## Data model (sketch)

- `Position`: 64 squares, side to move, castling rights, en passant square, halfmove and fullmove. Immutable. `fromFen`/`toFen`.
- `Move`: from, to, promotion, flag (quiet, double push, castle, en passant).
- `Idea` (enum): `fork`, `pin`, `skewer`, `discoveredAttack`, `hangingPiece`, `backRankMate`, ...
- `Insight`:
  - `idea`
  - `move` (and `line`, the follow-up moves)
  - `highlightSquares`, `arrows` (for the UI to draw the pattern)
  - `gain` (material or "mate in N")
  - `explanation` (template filled with real names)
- `IdeaDetector` interface: `Insight? find(Position pos, Move move)` plus `List<Insight> scan(Position pos)`.
- `Explainer`: runs detectors easiest first, returns the simplest account of a move.
- `Eval`: named terms (material, center, development, king safety, mobility, pawn structure). `EvalBreakdown diff(before, after)` feeds the "why" text.
- `Search`: alpha-beta with quiescence, mate-in-N finder. Used to verify, never to teach.

## Project layout

```
chess_solver/
  PLAN.md  CLAUDE.md  README.md
  pubspec.yaml
  lib/
    main.dart
    engine/                     pure Dart, no Flutter imports
      piece.dart                piece/colour encoding, square helpers
      move.dart
      position.dart             board, FEN, legal moves, check, perft
      search.dart               alpha-beta, mate-in-N
      eval.dart                 named eval terms + breakdown diff
      insight.dart              Idea enum, Insight
      explainer.dart            runs detectors, picks simplest account
      rater.dart                puzzle rating: idea that wins the most + tier
      puzzle.dart               Puzzle model
      ideas/
        hanging_piece.dart
        fork.dart
        pin.dart
        skewer.dart
        discovered.dart
        back_rank.dart
        mate_patterns.dart
        removing_defender.dart
        ...
    lessons/lessons.dart        GENERATED from tool/lessons_data.py
    puzzles/library.dart        GENERATED by tool/curate.py + gen_library.py
    progress/                   stars, unlocks, saved games (as sudoku)
    ui/                         board view, hint ladder, learn tab, practice tab, daily
  test/engine/                  perft, FEN, one hand-built position per idea, soundness
  tool/
    solve.dart                  CLI: explain a FEN
    curate.py                   dig puzzles from sample games into library.json (+ gen_library.py, gen_lessons.py, Python mirrors)
  tool/*_mirror.py, check_mirror.py   Python mirrors used to verify engine logic without a Dart SDK
```

## Build order

1. **Engine foundation:** `piece`, `move`, `position` (FEN in/out, legal moves, check/mate/stalemate). Prove with **perft**. Do not continue until these pass:
   - start position: 20, 400, 8902, 197281
   - Kiwipete `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1`: 48, 2039, 97862
   - `8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1`: 14, 191, 2812, 43238
   - `r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1`: 6, 264, 9467
   - `rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8`: 44, 1486, 62379
   Status: Dart written, logic verified via `tool/perft_mirror.py`; Dart compiled; `flutter test` passes.
2. **Search:** alpha-beta, quiescence, mate-in-N finder, CLI `tool/solve.dart <fen>`.
   Status: Dart written (`search.dart`, `solve.dart`, `search_test.dart`); logic verified via `tool/check_mirror.py`; Dart compiled; `flutter test` passes.
3. **Eval with named terms** and breakdown diff (material, center, development, king safety). First "why" text from these.
   Status: Dart written (`eval.dart`, `eval_test.dart`); logic verified via `tool/check_mirror.py`; Dart compiled; `flutter test` passes.
4. **Level 3 ideas:** hanging piece, trade evaluation, center, development, king safety.
   Status: hanging piece (static exchange), castling, development, center done (Dart written, Python-verified). Trade explanations and king safety text still to do.
5. **Level 4 ideas:** fork, pin, skewer, discovered attack, double check, back-rank, removing defender, mate patterns. Each with a test position and an explanation template.
   Status: checkmate, back-rank mate, smothered mate, double check, fork, discovered attack, removing the defender, pin, skewer done (`lib/engine/ideas/`, `explainer.dart`; Python-verified). Material claims go through `explainVerified` (2-ply material search). Also done: SAN names (`san.dart`) and "why is my move bad" (`mistakes.dart`). Still to do: deflection, Greek gift, trade and king-safety text, X-ray and zwischenzug ideas.
6. **Rater + puzzle finder** (puzzles whose best move needs exactly idea X). Curate a library.
   Status: `rater.dart` + `puzzle.dart` + generated `lib/puzzles/library.dart` done (Python-verified; Dart re-rates every entry in `test/puzzle_library_test.dart`, passing). Library is small; run `tool/curate.py` longer for more, esp. discovered attack, removing the defender, mate in 2/3. Pins and double check are lessons only: they do not win material by themselves, so they cannot be "one clear answer" puzzles yet.
7. **Flutter UI slice 1:** board view (tap to move, legal-move dots), set up position / paste FEN, "Show best move" with highlighted pattern and arrows, undo.
8. **Lessons** (Learn tab): level 1 rules lessons, then one per idea with a before/after worked example found by the real engine.
   Status: lesson content done (`lib/lessons/lessons.dart`, generated from `tool/lessons_data.py`, 26 lessons, every example checked by the engine). Learn tab UI written (`lib/ui/learn_screen.dart`, `lesson_screen.dart`).
9. **Hint ladder:** where to look, which idea, full move. Mistake feedback: "your move loses the knight to a fork on d5".
10. **Progress:** stars, unlocks by level, saved games, daily puzzle, random puzzle by level.
11. **Level 2 and 5:** basic mates and endgames.
12. **Stretch:** level 6 strategy, board photo scan (as sudoku's Tesseract scan, but piece recognition is harder), optional Stockfish checker in tests only.

## Testing approach

- Perft is the foundation test. Move generation wrong means every explanation wrong.
- Each idea: a minimal hand-built position where exactly that idea applies, with assertions on move, gain and key squares. This is also the lesson's worked example.
- Soundness: replay puzzles and games, assert a detector never claims a gain the search refutes.
- Explanations: golden-string tests for templates, so wording changes are deliberate.
- Puzzle library: every puzzle replayed step by step against search (as sudoku's library_soundness_test).

## Definition of done (engine milestone)

- Move generation passes all perft counts above.
- Search finds mate-in-1/2/3 on a test suite.
- Levels 3 and 4 ideas each have a detector, a test position and a plain-language explanation.
- `dart run tool/solve.dart "<fen>"` prints best move, the idea behind it, and why.
- No detector ever claims something the search refutes.

## Open questions

- Puzzle source: generate our own (positions found by search + rater) or hand-pick from public collections (Lichess puzzle DB is CC0).
- Piece art: bundled SVG set (needs a permissive license) or Unicode glyphs for v1.
- How deep to go on level 6 before it becomes hand-wavy.
