# Sample-game generator shared by the Python checks and the puzzle curator.
import random
from perft_mirror import Pos
from mirror_search import quiesce, material_eval, MATE

START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"


def sensible_game(rng, max_plies=70):
    """Greedy-ish play (best material after captures settle, 20% random)
    so positions look like real games instead of random mush."""
    pos = Pos(START)
    seen = [pos]
    for _ in range(max_plies):
        ms = pos.legal()
        if not ms:
            break
        if rng.random() < 0.2:
            mv = rng.choice(ms)
        else:
            scored = [(-quiesce(pos.make(m), -MATE - 1, MATE + 1, 1, material_eval) + rng.random() * 30, m)
                      for m in ms]
            mv = max(scored, key=lambda t: t[0])[1]
        pos = pos.make(mv)
        seen.append(pos)
    return seen


def to_fen(pos):
    ch = {1: 'p', 2: 'n', 3: 'b', 4: 'r', 5: 'q', 6: 'k'}
    rows = []
    for r in range(7, -1, -1):
        row, gap = '', 0
        for f in range(8):
            p = pos.sq[r * 8 + f]
            if not p:
                gap += 1
                continue
            if gap:
                row += str(gap)
                gap = 0
            c = ch[p & 7]
            row += c.upper() if p >> 3 == 0 else c
        if gap:
            row += str(gap)
        rows.append(row)
    rights = ''.join(c for bit, c in ((1, 'K'), (2, 'Q'), (4, 'k'), (8, 'q')) if pos.cast & bit) or '-'
    ep = '-' if pos.ep < 0 else 'abcdefgh'[pos.ep & 7] + str((pos.ep >> 3) + 1)
    return f"{'/'.join(rows)} {'w' if pos.turn == 0 else 'b'} {rights} {ep} 0 1"
