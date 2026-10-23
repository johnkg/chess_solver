# Checks for explain_mistake. Run: python3 tool/check_mistakes.py
import sys
from perft_mirror import Pos
from mirror_mistakes import explain_mistake

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


def uci_of(m):
    n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
    return n(m[0]) + n(m[1]) + ('' if not m[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[m[2]])


def critique(fen, uci, depth=3):
    pos = Pos(fen)
    mv = [m for m in pos.legal() if uci_of(m) == uci][0]
    return explain_mistake(pos, mv, depth)


cases = [
    # name, fen, played move, expected kind (None = fine), words the text must contain
    ('hangs a rook to the queen', '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d4', 'losesMaterial', ['Qxd4', 'Better was Rxd5']),
    ('misses back-rank mate in 1', '3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', 'g1f1', 'missesMate', ['Rxd8#', 'misses a forced mate']),
    ('allows back-rank mate', '3r2k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1', 'b1b2', 'allowsMate', ['Rd1#', 'allows']),
    ('walks into a knight fork', '6k1/8/8/8/4n3/8/P7/3R3K w - - 0 1', 'a2a3', 'losesMaterial', ['Nf2+', 'forks']),
    ('a sound opening move is fine', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'e2e4', None, []),
    ('taking the free queen is fine', '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d5', None, []),
]
for name, fen, uci, kind, words in cases:
    r = critique(fen, uci)
    got_kind = r['kind'] if r else None
    ok = got_kind == kind and all(w in (r['text'] if r else '') for w in words)
    check(name, ok, (got_kind or 'fine') + (' | ' + r['text'] if r else ''))

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
