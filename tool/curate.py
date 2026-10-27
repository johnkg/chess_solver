# Dig a puzzle library out of sample games plus hand-built seeds.
#   python3 tool/curate.py [minutes] [first-game-seed]   (defaults: 10, 1)
# Re-run with a new first-game-seed to add more puzzles; earlier finds are kept.
# Writes tool/library.json and lib/puzzles/library.dart.
# Every entry passes mirror_rater.rate(); the Dart test re-rates each one.
import json
import os
import random
import sys
import time
from multiprocessing import Pool

from perft_mirror import Pos
from mirror_games import sensible_game, to_fen
from mirror_ideas import explain
from mirror_rater import rate, TIER, MATE_TIER
from mirror_search import random_game_positions

HERE = os.path.dirname(os.path.abspath(__file__))
QUOTA = 10
PROPOSERS = {'hangingPiece', 'fork', 'skewer', 'removingDefender', 'discoveredAttack', 'doubleCheck'}

SEEDS = [
    '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1',                       # free queen
    '3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1',                       # knight fork king + rook
    '7q/8/8/7k/8/K7/8/R7 w - - 0 1',                          # skewer king then queen
    '4k3/3q4/8/8/4N3/8/8/4R1K1 w - - 0 1',                    # discovered double check wins the queen
    '4k3/8/8/3q4/4B3/8/8/4R1K1 w - - 0 1',                    # discovered check, bishop takes queen
    '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1',                      # smothered mate
    '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',                   # back-rank mate
    '3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',                # back-rank mate, take the rook
    'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',  # scholar's mate
    '7k/8/8/8/8/8/R7/1R4K1 w - - 0 1',                       # ladder mate in 2
]


MOST = {'q': 1, 'r': 2, 'b': 2, 'n': 2}


def plausible(fen):
    """No side has more pieces than it started with: random games promote pawns, which
    gives odd-looking puzzles (three rooks)."""
    board = fen.split()[0]
    return all(board.count(c) <= n and board.count(c.upper()) <= n for c, n in MOST.items())


def bucket(r):
    return f"mate{r['mate_in']}" if r['mate_in'] >= 2 else r['idea']


def entry(pos, r, source):
    return {'fen': to_fen(pos), 'solutions': r['solutions'], 'san': r['san'], 'idea': r['idea'],
            'tier': r['tier'], 'mate_in': r['mate_in'], 'text': r['text'], 'source': source}


def work(seed):
    """All clean puzzles found in one sample game (plus one random game for mates)."""
    rng = random.Random(seed)
    found = []
    seen = sensible_game(rng, max_plies=60)
    for pos in seen[10::2][:14]:
        moves = pos.legal()
        if not moves:
            continue
        if not any(i['idea'] in PROPOSERS for m in moves for i in explain(pos, m)):
            continue
        r = rate(pos, max_mate=1)
        if r:
            found.append(entry(pos, r, f'game{seed}'))
    rng2 = random.Random(seed + 10_000_000)
    seen, mated = random_game_positions(rng2, max_plies=120)
    if mated and len(seen) >= 8:
        for back, n in ((2, 1), (4, 2), (6, 3)):
            pos = seen[-back]
            if sum(1 for p in pos.sq if p) > 18:
                continue
            r = rate(pos, max_mate=n)
            if r and r['mate_in'] == n:
                found.append(entry(pos, r, f'mate{seed}'))
    return found


def main(minutes, start=1):
    deadline = time.time() + minutes * 60
    lib, counts, boards = [], {}, set()

    used_sources = set()

    def add(e):
        key = e['fen'].split()[0]
        b = f"mate{e['mate_in']}" if e['mate_in'] >= 2 else e['idea']
        if key in boards or counts.get(b, 0) >= QUOTA or not plausible(e['fen']):
            return False
        if e['source'] != 'hand' and e['source'][-1:].isdigit() and e['source'] in used_sources:
            return False  # one puzzle per game: neighbours in one game look alike
        used_sources.add(e['source'])
        boards.add(key)
        counts[b] = counts.get(b, 0) + 1
        lib.append(e)
        return True

    old = os.path.join(HERE, 'library.json')
    if os.path.exists(old):  # keep earlier finds, re-rated with the current rater
        with open(old) as f:
            for e in json.load(f):
                pos = Pos(e['fen'])
                r = rate(pos, max_mate=max(e['mate_in'], 1))
                if r:
                    add(entry(pos, r, e['source']))
    for fen in SEEDS:
        pos = Pos(fen)
        r = rate(pos)
        if r is None:
            print('seed rejected by rater:', fen)
        else:
            add(entry(pos, r, 'hand'))
    print('after seeds:', counts, flush=True)

    wanted = [b for b in list(PROPOSERS - {'doubleCheck'}) + ['checkmate', 'backRankMate', 'smotheredMate', 'mate2', 'mate3']]
    with Pool(2) as pool:
        for n, found in enumerate(pool.imap_unordered(work, range(start, start + 100000))):
            for e in found:
                if add(e):
                    print(f"  +{(e['idea'] or 'mate' + str(e['mate_in']))} from {e['source']}", flush=True)
            if all(counts.get(b, 0) >= QUOTA for b in wanted) or time.time() > deadline:
                print(f'stopping after {n + 1} games', flush=True)
                pool.terminate()
                break

    lib.sort(key=lambda e: (e['tier'], e['idea'] or '', e['mate_in'], e['fen']))
    seq = {}
    for e in lib:
        b = f"mate{e['mate_in']}" if e['mate_in'] >= 2 else e['idea']
        seq[b] = seq.get(b, 0) + 1
        e['id'] = f'{b}-{seq[b]}'
    with open(os.path.join(HERE, 'library.json'), 'w') as f:
        json.dump(lib, f, indent=1)
    print('final:', {b: sum(1 for e in lib if (f"mate{e['mate_in']}" if e['mate_in'] >= 2 else e['idea']) == b) for b in sorted(seq)})
    print('total', len(lib))


if __name__ == '__main__':
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 10, int(sys.argv[2]) if len(sys.argv) > 2 else 1)
