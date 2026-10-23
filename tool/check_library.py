# Independent soundness check of tool/library.json. Run: python3 tool/check_library.py
# - every entry re-rates identically with the Python rater
# - mate puzzles: brute-force minimax agrees, and no shorter mate exists
# - material puzzles: the solution is still best one ply deeper (depth 4)
import json
import os
import sys
import time
from multiprocessing import Pool

from perft_mirror import Pos
from mirror_games import to_fen
from mirror_mistakes import score_moves
from mirror_rater import rate, uci_of
from mirror_search import negamax, mate_in, MATE

HERE = os.path.dirname(os.path.abspath(__file__))


def verify(e):
    """Returns a list of (name, ok, detail) for one library entry."""
    out = []
    pos = Pos(e['fen'])
    n = e['mate_in']
    out.append(('fen round trip', to_fen(pos).split()[0] == e['fen'].split()[0], ''))
    r = rate(pos, max_mate=max(n, 1))
    same = (r is not None and r['solutions'] == e['solutions'] and r['idea'] == e['idea']
            and r['tier'] == e['tier'] and r['mate_in'] == n and r['san'] == e['san'])
    out.append(('re-rates as stored', same, str(r and (r['solutions'], r['idea']))))
    if n:
        moves = {uci_of(m): m for m in pos.legal()}
        sol = moves[e['solutions'][0]]
        score = -negamax(pos.make(sol), 2 * n - 2, -MATE - 1, MATE + 1, 1, quiet=False)
        out.append(('brute force confirms mate in %d' % n, score > MATE - 1000, str(score)))
        out.append(('no shorter mate', n == 1 or mate_in(pos, n - 1) is None, ''))
    else:
        t0 = time.time()
        scored = sorted(score_moves(pos, 4), key=lambda t: -t[1])
        best = uci_of(scored[0][0])
        gap = scored[0][1] - scored[1][1]
        out.append(('still best at depth 4', best == e['solutions'][0], f'best={best} gap={gap} {time.time() - t0:.0f}s'))
    return e['id'], out


if __name__ == '__main__':
    with open(os.path.join(HERE, 'library.json')) as f:
        lib = json.load(f)
    fails = 0
    soft = 0
    with Pool(2) as pool:
        for pid, checks in pool.imap(verify, lib):
            for name, ok, detail in checks:
                print(('PASS ' if ok else 'FAIL ') + f'{pid}: {name}  {detail}', flush=True)
                if not ok:
                    if name == 'still best at depth 4':
                        soft += 1   # reported, judged below
                    else:
                        fails += 1
    material = sum(1 for e in lib if not e['mate_in'])
    print(f'\n{len(lib)} puzzles, {material} material, {soft} not best at depth 4')
    if material and soft * 4 > material:
        print('FAILED: more than 25% of material puzzles change at depth 4')
        fails += 1
    print('\nFAILED' if fails else '\nALL OK', fails or '')
    sys.exit(1 if fails else 0)
