"""Exact results for positions with up to 7 pieces, from the free Lichess tablebase.

Used offline by check_lessons.py / check_drills.py for rook endings, where the
king-and-pawn table in tb_kpk.py does not apply. Answers are cached in
tb_cache.json, so the checks run without the network once a position is known.
Needs outbound access to tablebase.lichess.ovh only when a position is new.
"""
import json
import os
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, 'tb_cache.json')
URL = 'https://tablebase.lichess.ovh/standard?fen='
PAUSE = 0.5          # seconds between live requests; the service is shared
_cache = None


def _load():
    global _cache
    if _cache is None:
        _cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    return _cache


def _key(fen):
    return ' '.join(fen.split()[:4])      # the clocks do not change the result


def raw(fen):
    """Lichess answer for a position: category plus every legal move with its category."""
    cache = _load()
    k = _key(fen)
    if k not in cache:
        url = URL + _key(fen).replace(' ', '_')
        for attempt in range(4):
            try:
                with urllib.request.urlopen(url, timeout=30) as r:
                    data = json.load(r)
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)
        # Keep only what the checks use.
        cache[k] = {'category': data['category'],
                    'moves': {m['uci']: m['category'] for m in data['moves']}}
        json.dump(cache, open(CACHE, 'w'), indent=0, sort_keys=True)
        time.sleep(PAUSE)
    return cache[k]


FLIP = {'win': 'loss', 'loss': 'win', 'draw': 'draw',
        'cursed-win': 'blessed-loss', 'blessed-loss': 'cursed-win',
        'maybe-win': 'maybe-loss', 'maybe-loss': 'maybe-win'}


def result(fen):
    """Result for the side to move: 'win', 'draw' or 'loss' (50-move-rule wins and losses are not counted)."""
    return raw(fen)['category']


def results_by_move(fen):
    """{uci: result for the side that plays it}. A move's category is the opponent's view of the next position."""
    return {u: FLIP[c] for u, c in raw(fen)['moves'].items()}


def best_moves(fen):
    """The moves that keep the best result available."""
    r = results_by_move(fen)
    order = ['win', 'cursed-win', 'maybe-win', 'draw', 'blessed-loss', 'maybe-loss', 'loss']
    best = min(r.values(), key=order.index)
    return sorted(u for u, c in r.items() if c == best)
