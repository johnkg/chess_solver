# Builds hand-made puzzle positions for the mate categories that random games rarely
# reach (back-rank mates, smothered mates, mate in 2 and 3). A fixed pattern (king with
# its pawn shelter, or a bare king) gets a few random extra pieces; only positions that
# mirror_rater accepts as a clean one-solution puzzle are kept.
#   python3 tool/gen_hand.py [minutes]   -> tool/hand_seeds.json (read by curate.py)
import json
import os
import random
import sys
import time
from multiprocessing import Pool

from perft_mirror import Pos, W, Bk
from mirror_games import to_fen
from mirror_rater import rate

HERE = os.path.dirname(os.path.abspath(__file__))
WANT = {'backRankMate': 10, 'smotheredMate': 12, 'mate2': 22, 'mate3': 22}

# (black king + shelter, white shelter) base patterns, as {square: piece}
BASES = [
    ({'g8': 'k', 'f7': 'p', 'g7': 'p', 'h7': 'p'}, {'g1': 'K', 'f2': 'P', 'g2': 'P', 'h2': 'P'}),
    ({'g8': 'k', 'f7': 'p', 'g6': 'p', 'h7': 'p'}, {'g1': 'K', 'f2': 'P', 'g2': 'P', 'h3': 'P'}),
    ({'h8': 'k', 'g7': 'p', 'h7': 'p'}, {'h1': 'K', 'g2': 'P', 'h2': 'P'}),
    ({'b8': 'k', 'a7': 'p', 'b7': 'p', 'c7': 'p'}, {'b1': 'K', 'a2': 'P', 'b2': 'P', 'c2': 'P'}),
    ({'h8': 'k', 'g8': 'r', 'g7': 'p', 'h7': 'p'}, {'g1': 'K', 'f2': 'P', 'g2': 'P'}),
    ({'g8': 'k'}, {'g1': 'K'}),
    ({'a8': 'k'}, {'h1': 'K'}),
    ({'e8': 'k', 'd7': 'p', 'e7': 'p', 'f7': 'p'}, {'e1': 'K', 'f2': 'P'}),
]
WHITE_EXTRAS = ['Q', 'R', 'R', 'N', 'N', 'B']
BLACK_EXTRAS = ['r', 'n', 'b', 'p', 'p', 'q']


def name(s):
    return 'abcdefgh'.index(s[0]), int(s[1]) - 1


def candidate(rng):
    black, white = rng.choice(BASES)
    board = {}
    for src in (black, white):
        for s, p in src.items():
            board[s] = p
    free = [f + r for f in 'abcdefgh' for r in '12345678' if f + r not in board]
    free = [s for s in free if s[1] not in ('1', '8') or True]
    for p in rng.sample(WHITE_EXTRAS, rng.choice([1, 2, 2, 3])):
        board[rng.choice(free)] = p
    for p in rng.sample(BLACK_EXTRAS, rng.choice([0, 1, 2])):
        board[rng.choice(free)] = p
    rows = []
    for r in range(7, -1, -1):
        row, gap = '', 0
        for f in range(8):
            p = board.get('abcdefgh'[f] + str(r + 1))
            if p is None:
                gap += 1
            else:
                row += (str(gap) if gap else '') + p
                gap = 0
        rows.append(row + (str(gap) if gap else ''))
    return '/'.join(rows) + ' w - - 0 1'


def legal_start(fen):
    """Pawns not on the first or last rank, kings apart, black not in check, white has a move."""
    rows = fen.split()[0].split('/')
    if 'P' in rows[0] or 'p' in rows[0] or 'P' in rows[7] or 'p' in rows[7]:
        return None
    try:
        pos = Pos(fen)
    except Exception:
        return None
    wk = [i for i in range(64) if pos.sq[i] == (pos.sq[i] if False else 0)]
    ks = {W: None, Bk: None}
    from perft_mirror import K, mk
    cnt = {W: 0, Bk: 0}
    for i in range(64):
        for c in (W, Bk):
            if pos.sq[i] == mk(K, c):
                ks[c] = i
                cnt[c] += 1
    if cnt[W] != 1 or cnt[Bk] != 1:
        return None
    if pos.attacked(ks[Bk], W):
        return None
    if pos.attacked(ks[W], Bk):
        return None
    return pos


def work(seed):
    rng = random.Random(seed)
    out = []
    for _ in range(30):
        fen = candidate(rng)
        if len(fen.split()[0].replace('/', '').replace('1', '')) > 0 and sum(c.isalpha() for c in fen.split()[0]) > 11:
            continue
        pos = legal_start(fen)
        if pos is None or not pos.legal():
            continue
        r = rate(pos, max_mate=3)
        if r is None:
            continue
        b = f"mate{r['mate_in']}" if r['mate_in'] >= 2 else r['idea']
        if b in WANT:
            out.append((b, to_fen(pos), r['san']))
    return out


def main(minutes):
    deadline = time.time() + minutes * 60
    got = {b: [] for b in WANT}
    seen = set()
    with Pool(2) as pool:
        for n, found in enumerate(pool.imap_unordered(work, range(1, 10**6))):
            for b, fen, s in found:
                key = fen.split()[0]
                if key in seen or len(got[b]) >= WANT[b]:
                    continue
                seen.add(key)
                got[b].append(fen)
                print(b, s, fen, flush=True)
            if all(len(got[b]) >= WANT[b] for b in WANT) or time.time() > deadline:
                pool.terminate()
                break
    with open(os.path.join(HERE, 'hand_seeds.json'), 'w') as f:
        json.dump([fen for b in WANT for fen in got[b]], f, indent=1)
    print({b: len(v) for b, v in got.items()})


if __name__ == '__main__':
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 10)
