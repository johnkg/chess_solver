# Checks for the Python idea mirror. Run: python3 tool/check_ideas.py
import random
import sys
from perft_mirror import Pos, W, Bk
from mirror_search import negamax, material_eval, random_game_positions, MATE, in_check, quiesce
from mirror_ideas import explain, see_capture, sqname, PV

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


def mv_of(pos, uci):
    for m in pos.legal():
        n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
        u = n(m[0]) + n(m[1]) + ('' if not m[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[m[2]])
        if u == uci:
            return m
    raise ValueError(uci)


def ideas(fen, uci):
    pos = Pos(fen)
    return {i['idea']: i for i in explain(pos, mv_of(pos, uci))}


# ---- hand-built positions: (name, fen, move, must-have idea or None, must-not-have)
cases = [
    ('knight fork king+rook', '3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7', 'fork', None),
    ('knight fork refused when forker is capturable', '3kb2r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7', None, 'fork'),
    ('absolute pin (Bb5 vs Nc6 / Ke8)', 'r1bqkbnr/ppp2ppp/2np4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 4', 'f1b5', 'pin', None),
    ('no pin when the piece behind is only a pawn', 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3', 'f1b5', None, 'pin'),
    ('relative pin (Re2 vs Ne4 / Qe8)', '4q1k1/8/8/8/4n3/8/R7/3K4 w - - 0 1', 'a2e2', 'pin', None),
    ('skewer king then queen', '7q/8/8/7k/8/K7/8/R7 w - - 0 1', 'a1h1', 'skewer', None),
    ('free queen', '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d5', 'hangingPiece', None),
    ('rook for defended pawn is NOT a win', '4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1', 'd1d5', None, 'hangingPiece'),
    ('queen takes pawn defended by pawn is NOT a win', '4k3/8/2p5/3p4/8/8/8/3QK3 w - - 0 1', 'd1d5', None, 'hangingPiece'),
    ('pawn takes defended queen wins material', '4k3/8/2p5/3q4/4P3/8/8/4K3 w - - 0 1', 'e4d5', 'hangingPiece', None),
    ('back-rank mate', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1', 'a1a8', 'backRankMate', 'checkmate'),
    ("scholar's mate is checkmate, not back rank", 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4', 'h5f7', 'checkmate', 'backRankMate'),
    ('development', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'g1f3', 'development', None),
    ('center pawn move', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'e2e4', 'center', None),
    ('castling', 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1', 'e1g1', 'castling', None),
]
for name, fen, uci, want, notwant in cases:
    got = ideas(fen, uci)
    ok = (want is None or want in got) and (notwant is None or notwant not in got)
    check(name, ok, str(sorted(got)))

# ---- text sanity: real names appear
t = ideas('3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7')['fork']['text']
check('fork text names squares and pieces', all(w in t for w in ('Knight', 'f7', 'd8', 'h8', 'king', 'rook')), t)
t = ideas('r1bqkbnr/ppp2ppp/2np4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 4', 'f1b5')['pin']['text']
check('pin text', 'bishop on b5 pins the knight on c6 to the king on e8' in t, t)

# ---- SEE unit checks
pos = Pos('4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1')
check('SEE rook x defended pawn = -400', see_capture(pos, mv_of(pos, 'd1d5')) == -400)
pos = Pos('4k3/8/8/3p4/8/8/8/3RK3 w - - 0 1')
check('SEE rook x loose pawn = +100', see_capture(pos, mv_of(pos, 'd1d5')) == 100)

# ---- soundness: do claimed gains survive a 2-ply material search?
from mirror_ideas import margin, explain_verified, MATERIAL_IDEAS
from mirror_games import sensible_game, to_fen


rng = random.Random(777)
proposed = {k: 0 for k in MATERIAL_IDEAS}
verified = {k: 0 for k in MATERIAL_IDEAS}
deep_ok = {k: 0 for k in MATERIAL_IDEAS}
games = 0
while games < 25 and min(proposed[b] for b in ('hangingPiece', 'fork', 'skewer')) < 60:
    games += 1
    seen = sensible_game(rng)
    for pos in seen[10::3]:
        if in_check(pos):
            continue
        for m in pos.legal():
            for ins in explain(pos, m):
                k = ins['idea']
                if k not in MATERIAL_IDEAS or proposed[k] >= 60:
                    continue
                proposed[k] += 1
                if margin(pos, m) >= ins['gain']:
                    verified[k] += 1
                    if margin(pos, m, depth=3) >= ins['gain'] - 100:
                        deep_ok[k] += 1
                    elif deep_ok[k] + 1 and verified[k] - deep_ok[k] <= 2:
                        print('   depth-3 disagreement:', k, sqname(m[0]) + sqname(m[1]), 'claimed', ins['gain'], to_fen(pos))
for k in MATERIAL_IDEAS:
    print(f'   {k}: proposed {proposed[k]}, passed 2-ply verification {verified[k]}, '
          f'still hold at 3 plies (within a pawn) {deep_ok[k]}')
BASE = ('hangingPiece', 'fork', 'skewer')
check('detectors propose claims on real-looking positions', all(proposed[k] >= 10 for k in BASE), str(proposed))
check('verified claims hold at depth 3 at least 75% of the time',
      all(verified[k] == 0 or deep_ok[k] * 4 >= verified[k] * 3 for k in MATERIAL_IDEAS),
      str({k: (deep_ok[k], verified[k]) for k in MATERIAL_IDEAS}))
# hand-built cases survive verification
for name, fen, uci, want, _ in cases:
    if want in MATERIAL_IDEAS:
        pos = Pos(fen)
        got = {i['idea'] for i in explain_verified(pos, mv_of(pos, uci))}
        check('verification keeps: ' + name, want in got, str(got))

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
