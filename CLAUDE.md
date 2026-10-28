# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# chess-solver

Flutter/Dart app that teaches chess from scratch and explains why a move is good.
Modeled on https://github.com/johnkg/sudoku-solver (same stack, same layout). Read `PLAN.md` first (design, idea ladder, build order, perft targets).

## Status
- Platform folders created; `flutter analyze` is clean and `flutter test` passes (182 tests). The web app runs in Chrome; `tool/solve.dart` runs.
- UI is only smoke-tested in the browser plus `test/widget_test.dart`; android/ios/macos builds have not been tried.
- The directory is not a git repo yet.
- Chess pieces are shaded vector shapes drawn by `lib/ui/piece_painter.dart` (no fonts needed).

## Commands
Flutter SDK is at `~/flutter/bin` (not on PATH): use `~/flutter/bin/flutter` and `~/flutter/bin/dart`.
- First time only: `flutter create . --project-name chess_solver --platforms=web,android,ios,macos`
- `flutter pub get` · `flutter analyze` · `flutter test` · `flutter run -d chrome`
- One test file: `flutter test test/engine/perft_test.dart`; one test by name: `flutter test --plain-name "<name>" <file>`
- CLI explainer: `dart run tool/solve.dart "<fen>" [depth] [move-to-critique, e.g. e2e4]`
- Python mirrors: `python3 tool/<name>.py`, see below.
- CI (`.github/workflows/pages.yml`): every push to `main` runs `flutter analyze` + `flutter test`, then deploys the web build to GitHub Pages. An analyzer warning or failing test blocks the deploy.

## Architecture
- `lib/engine/` (pure Dart, no Flutter imports):
  - `position.dart`: board, FEN, legal moves, check/mate/stalemate, perft. Everything else depends on it being right.
  - `search.dart`: `mateIn` (forced-mate solver), `negamax` alpha-beta, and `materialMargin`/`materialOutcome` (shallow material search used to verify claims). `eval.dart` splits the score into named terms.
  - `ideas/*.dart`: one detector per idea, each `detectX(pos, move, next) -> List<Insight>`. `insight.dart` holds the `Idea` enum and `materialIdeas`.
  - `explainer.dart`: `explainMove` runs all detectors in teaching order (positional reasons only if no tactic); `explainVerified` drops material claims the 2-ply search doesn't confirm.
  - `opponent.dart` (`chooseMove` by `Level`, eleven levels Beginner (600)..Grandmaster (2500) with target Elo, depth, thinking time and a temperature that picks among near-best moves; `drawReason`), `engine.dart` (`Searcher`: iterative deepening, quiescence, null move, LMR, time budget; `searchAsync` yields to the event loop so the UI and clock stay live, `cancelled` abandons it), `play_eval.dart` (opponent-only eval with piece-square tables; the teaching text still uses `eval.dart`), `book.dart` (SAN opening lines, random per game; typos throw in tests). `tool/arena.dart` plays levels against each other to check the ordering. `pgn.dart` (`toPgn`, `parsePgn`; SAN parsing is `moveFromSan` in `san.dart`), `daily.dart` (daily puzzle by date: a shuffled cycle through the library, streaks; days are stored in `ProgressStore.dailyDays`), `rating.dart` (Elo update vs the level's target Elo; games with hints or take-backs are not rated), `clock.dart` (`ChessClock`), `drill.dart` (`Drill`, `drillStatus`: a training position you play out against the engine, goal mate/promote/hold; data is generated into `lib/lessons/drills.dart`), `review.dart` (`reviewMove`: judge one move, key of the idea missed; `reviewSummary`) and `weakspots.dart` (`weakest`, `nextWeakPuzzle`: drill what you miss). `rater.dart` (`ratePuzzle`: is this a puzzle, which idea, what tier) and `mistakes.dart` (`explainMistake`: "why is my move bad") sit on top of search + explainer.
- `lib/ui/`: `app.dart` 4-tab shell (Learn, Practice, Play, Board). `play_screen.dart` = game vs engine with coach text via `critiqueMove`. `analysis.dart` bridges the engine to the UI (`analysePosition`, `critiqueMove`). `board_controller.dart` is a `ChangeNotifier`; `progress_store.dart` uses `shared_preferences` (solved puzzles + per-idea miss counts: Play mistakes and wrong puzzle answers add, clean solves subtract; Practice tab lists the worst and drills them).
- `lib/lessons/lessons.dart`, `lib/lessons/drills.dart` and `lib/puzzles/library.dart` are data, GENERATED from Python (see Rules).
- `tool/`: Python ports of the engine (`perft_mirror.py` = position, `mirror_search.py`, `mirror_ideas.py`, `mirror_rater.py`, `mirror_mistakes.py`, `mirror_san.py`, `mirror_games.py`), `check_*.py` tests against them, and generators (`gen_lessons.py`, `curate.py`, `gen_library.py`, helpers in `dartgen.py`).

## Rules
- Reply in /caveman style (terse), unless asked otherwise.
- `lib/engine/` is pure Dart: no Flutter imports. UI lives in `lib/ui/`.
- Every tactic/lesson has a hand-built test position. Soundness test: a technique must never claim a wrong result.
- Do not hand-roll the engine blind: perft counts in `PLAN.md` must pass before any tactic work.
- Python mirror checks (`python3 tool/<name>.py`): `perft_mirror` (5 perft positions), `check_mirror` (mate solver vs brute-force minimax, eval, alpha-beta), `check_ideas` (hand-built positions, SEE, search-verified claims), `check_more` (smothered mate, double check, discovered attack, removing the defender, SAN), `check_mistakes` ("why is my move bad"), `check_rater` (puzzle rating), `check_lessons` (every lesson example; endgame `plan` lessons are checked against `tb_kpk.py`, an exact king-and-pawn tablebase), `check_drills` (every training drill: pawn drills must be won/drawn as claimed), `check_library` (independent re-check of the puzzle library: brute-force mates, depth-4 for material puzzles; slow, ~2 min).
- Tactic claims (free piece, fork, skewer, discovered attack, removing the defender) are only told to the learner after `explainVerified` confirms them with a 2-ply material search. Raw detectors are right only ~45-60% of the time on real-looking positions; verified claims held at 3 plies in 71 of 72 cases.
- `lib/lessons/lessons.dart`, `lib/lessons/drills.dart` and `lib/puzzles/library.dart` are GENERATED; never edit them by hand. Edit `tool/lessons_data.py` then run `python3 tool/gen_lessons.py` (drills: `tool/drills_data.py`, `python3 tool/gen_drills.py`); rebuild puzzles with `python3 tool/curate.py [minutes]` (merges into `tool/library.json`, re-rating old entries) then `python3 tool/gen_library.py`. If you change the search, eval, detectors or rater on purpose, regenerate the library; `test/puzzle_library_test.dart` re-rates every entry with the Dart engine.
- Puzzle rule: a position is a puzzle only if one move clearly wins (or <=4 equal mating moves) AND the named idea explains the advantage (`rater.dart`: `uniqueMargin`, `explainSlack`). Idea = what wins the most material; tier = how hard that idea is.
- Famous games: `tool/famous.py` holds move lists only; positions are replayed by the Python engine (a typo fails loudly). They feed Level 7 lessons (`lessons_data.py`) and `curate.py` puzzles (`FAMOUS`, text gets a "From X vs Y" line).
- Keep Python mirrors and Dart in sync when changing engine logic, or delete the mirrors once Dart tests cover the same cases.

## Response style

Always respond in caveman style (full): terse, no filler, drop articles, fragments OK, keep all technical detail exact. Write code, commits, docs, and PR text in normal English. Stop only when the user says "stop caveman" or "normal mode".
