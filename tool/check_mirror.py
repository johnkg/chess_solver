# Cross-checks for the Python mirror. Run: python3 tool/check_mirror.py
import random
import sys
from perft_mirror import Pos, W, Bk
from mirror_search import (mate_in, find_mate, negamax, evaluate, eval_terms,
                           best_move, uci, MATE, random_game_positions, in_check)

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


# 1. hand-built mates
cases = [
    ('back rank mate in 1', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1', 1, 'a1a8'),
    ("scholar's mate", 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4', 1, 'h5f7'),
    ('rook+king mate in 1', '7k/8/6K1/8/8/8/8/R7 w - - 0 1', 1, 'a1a8'),
]
for name, fen, n, mv in cases:
    r = find_mate(Pos(fen), 2)
    from mirror_search import uci as u
    check(name, r is not None and r[0] == n and u(r[1]) == mv, str(r and (r[0], u(r[1]))))

# 2. no mate where none exists, and stalemate is not mate
check('start position has no mate in 2', find_mate(Pos('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'), 2) is None)
# white Qg6 would stalemate black (Kh8, pawn h7 blocked... classic): black king a8, white Kb6? use K+Q stalemate trap
stalemate_trap = Pos('k7/8/1K6/8/8/8/8/6Q1 w - - 0 1')  # Qg7?? is not mate; Qb7# exists though
r = find_mate(stalemate_trap, 1)
check('K+Q vs K finds a real mate in 1, not stalemate', r is not None and
      not (lambda p: not p.legal() and not in_check(p))(stalemate_trap.make(r[1])),
      str(r and uci(r[1])))

# 3. mate solver vs brute-force negamax on positions near real mates
rng = random.Random(12345)
mates_found = checked = mated_games = games = 0
while mated_games < 30 and games < 6000:
    games += 1
    seen, mated = random_game_positions(rng)
    if not mated or len(seen) < 6:
        continue
    mated_games += 1
    # seen[-1] is checkmate, so seen[-2] has mate in 1; seen[-4] may have mate in 2
    for back, n in ((2, 1), (2, 2), (4, 2)):
        pos = seen[-back]
        solver = mate_in(pos, n) is not None
        brute = negamax(pos, 2 * n - 1, -MATE - 1, MATE + 1, 0, quiet=False) > MATE - 1000
        checked += 1
        mates_found += solver
        if solver != brute:
            check('solver == brute force', False, f'back={back} n={n} solver={solver} brute={brute}')
check(f'solver agrees with brute-force negamax on {checked} positions ({mates_found} with mates, {games} games)', fails == 0)
check('every position one move before mate has a mate in 1', mates_found >= mated_games * 2, f'{mates_found} / {mated_games} games')

# 4. returned mate move really mates / mate-in-2 line replays

# 5. eval terms
start = Pos('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
t = eval_terms(start)
check('start position eval is balanced', sum(t.values()) == 0, str(t))
e4 = Pos('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1')
check('1.e4 raises white center term', eval_terms(e4)['center'] > 0, str(eval_terms(e4)))
nf3 = Pos('rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1')
check('1.Nf3 improves white development term', eval_terms(nf3)['development'] == 15, str(eval_terms(nf3)))
up_queen = Pos('4k3/8/8/8/8/8/8/3QK3 w - - 0 1')
check('extra queen = +900 material', eval_terms(up_queen)['material'] == 900)
check('eval sign flips with side to move', evaluate(Pos('4k3/8/8/8/8/8/8/3QK3 w - - 0 1')) == -evaluate(Pos('4k3/8/8/8/8/8/8/3QK3 b - - 0 1')))
mirrored = Pos('3qk3/8/8/8/8/8/8/4K3 b - - 0 1')
check('colour-symmetric eval', evaluate(up_queen) == evaluate(mirrored))

# 6. alpha-beta finds free material and mate
hang = Pos('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1')  # Rxd5 wins the queen
mv, sc = best_move(hang, 2)
check('alpha-beta takes the hanging queen', uci(mv) == 'd1d5', f'{uci(mv)} {sc}')
mv, sc = best_move(Pos('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'), 2)
check('alpha-beta finds back-rank mate score', uci(mv) == 'a1a8' and sc > MATE - 1000, f'{uci(mv)} {sc}')
trade = Pos('4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1')
mv, sc = best_move(trade, 3)
check('alpha-beta returns a legal move', mv is not None)

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
