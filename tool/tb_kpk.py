# Exact king-and-pawn-versus-king solver (a tiny tablebase), so endgame lessons
# can be checked instead of trusted.  Squares: a1 = 0 ... h8 = 63.
#
#   from tb_kpk import kpk
#   kpk('4k3/8/4K3/4P3/8/8/8/8 w - - 0 1')   -> True  (the pawn side wins)
#
# Black pawn positions are mirrored (flip ranks, swap colours) before lookup.
import sys

KING = [[] for _ in range(64)]
for s in range(64):
    f, r = s & 7, s >> 3
    for df in (-1, 0, 1):
        for dr in (-1, 0, 1):
            if (df or dr) and 0 <= f + df < 8 and 0 <= r + dr < 8:
                KING[s].append((r + dr) * 8 + f + df)
ADJ = [set(KING[s]) | {s} for s in range(64)]


def pawn_attacks(p):
    f, r = p & 7, p >> 3
    out = []
    if r < 7:
        if f > 0:
            out.append(p + 7)
        if f < 7:
            out.append(p + 9)
    return out


def legal(wk, wp, bk, white_to_move):
    if len({wk, wp, bk}) < 3 or bk in ADJ[wk]:
        return False
    if not 1 <= (wp >> 3) <= 6:
        return False
    if white_to_move and bk in pawn_attacks(wp):
        return False
    return True


def promo_wins(wk, wp, bk):
    """The pawn reaches the last rank: can Black still hold? (After the pawn
    steps to wp+8 with Black to move.)"""
    q = wp + 8
    capturable = bk in ADJ[q] and q not in ADJ[wk]
    if capturable:
        return False
    # Stalemate with a queen? Then a rook would not be (it is fine unless
    # Black's king has no move at all and the rook also stalemates; a rook
    # attacks fewer squares, so it is always a win here).
    return True


def black_moves(wk, wp, bk):
    out = []
    att = set(pawn_attacks(wp))
    for t in KING[bk]:
        if t in ADJ[wk]:
            continue
        if t == wp:
            out.append(t)  # captures the unprotected pawn (wp not in ADJ[wk])
            continue
        if t in att:
            continue
        out.append(t)
    return out


def white_moves(wk, wp, bk):
    """Yield ('k', newwk), ('p', newwp) pairs."""
    for t in KING[wk]:
        if t == wp or t in ADJ[bk]:
            continue
        yield ('k', t)
    one = wp + 8
    if one != wk and one != bk:
        yield ('p', one)
        if (wp >> 3) == 1:
            two = wp + 16
            if two != wk and two != bk:
                yield ('p', two)


def solve():
    win_w = set()   # white to move, pawn side wins
    lost_b = set()  # black to move, pawn side wins
    states_w = [(a, p, b) for a in range(64) for p in range(8, 56) for b in range(64)
                if legal(a, p, b, True)]
    states_b = [(a, p, b) for a in range(64) for p in range(8, 56) for b in range(64)
                if legal(a, p, b, False)]
    changed = True
    while changed:
        changed = False
        for st in states_w:
            if st in win_w:
                continue
            wk, wp, bk = st
            for kind, t in white_moves(wk, wp, bk):
                if kind == 'k':
                    if (t, wp, bk) in lost_b:
                        win_w.add(st)
                        changed = True
                        break
                else:
                    if (t >> 3) == 7:
                        if promo_wins(wk, wp, bk):
                            win_w.add(st)
                            changed = True
                            break
                    elif (wk, t, bk) in lost_b:
                        win_w.add(st)
                        changed = True
                        break
        for st in states_b:
            if st in lost_b:
                continue
            wk, wp, bk = st
            moves = black_moves(wk, wp, bk)
            if not moves:
                in_check = bk in pawn_attacks(wp)
                if in_check:  # mated by the pawn
                    lost_b.add(st)
                    changed = True
                continue
            ok = True
            for t in moves:
                if t == wp or (wk, wp, t) not in win_w:
                    ok = False
                    break
            if ok:
                lost_b.add(st)
                changed = True
    return win_w, lost_b


_TB = None


def tables():
    global _TB
    if _TB is None:
        _TB = solve()
    return _TB


def parse(fen):
    """-> (wk, wp, bk, white_to_move) from the pawn owner's point of view."""
    board, turn = fen.split()[:2]
    pieces = []
    r = 7
    f = 0
    for ch in board:
        if ch == '/':
            r -= 1
            f = 0
        elif ch.isdigit():
            f += int(ch)
        else:
            pieces.append((ch, r * 8 + f))
            f += 1
    kinds = sorted(ch for ch, _ in pieces)
    if kinds not in (['K', 'P', 'k'], ['K', 'k', 'p']):
        raise ValueError('not a king-and-pawn-versus-king position: ' + fen)
    d = {ch: s for ch, s in pieces}
    if 'P' in d:
        return d['K'], d['P'], d['k'], turn == 'w'
    flip = lambda s: (7 - (s >> 3)) * 8 + (s & 7)
    return flip(d['k']), flip(d['p']), flip(d['K']), turn == 'b'


def kpk(fen):
    """True when the side owning the pawn wins, False when it is a draw."""
    wk, wp, bk, wtm = parse(fen)
    win_w, lost_b = tables()
    return (wk, wp, bk) in (win_w if wtm else lost_b)


def kpk_after(fen, uci):
    """After the move (any side), does the pawn side win? (None if illegal.)"""
    wk, wp, bk, wtm = parse(fen)
    a = ord(uci[0]) - 97 + (int(uci[1]) - 1) * 8
    b = ord(uci[2]) - 97 + (int(uci[3]) - 1) * 8
    flipped = 'P' not in [c for c in fen.split()[0]]
    if flipped:
        fl = lambda s: (7 - (s >> 3)) * 8 + (s & 7)
        a, b = fl(a), fl(b)
    win_w, lost_b = tables()
    if wtm:
        if a == wk:
            if b not in KING[wk] or b == wp or b in ADJ[bk]:
                return None
            return (b, wp, bk) in lost_b
        if a == wp:
            if b not in (wp + 8, wp + 16) or b == wk or b == bk:
                return None
            if b >> 3 == 7:
                return promo_wins(wk, wp, bk)
            return (wk, b, bk) in lost_b
        return None
    if a != bk or b not in black_moves(wk, wp, bk):
        return None
    return b != wp and (wk, wp, b) in win_w


if __name__ == '__main__':
    w, l = tables()
    print('white-to-move wins:', len(w), ' black-to-move lost:', len(l))
    # Known facts.
    tests = [
        ('4k3/8/4K3/4P3/8/8/8/8 w - - 0 1', True),    # king on 6th in front: wins
        ('4k3/8/4K3/4P3/8/8/8/8 b - - 0 1', True),
        ('k7/8/K7/P7/8/8/8/8 w - - 0 1', False),      # rook pawn, defender in corner
        ('7k/8/8/8/8/8/P7/K7 w - - 0 1', True),       # rook pawn, defender far away
        ('8/8/8/4k3/8/4K3/4P3/8 w - - 0 1', False),   # defender has the opposition
        ('8/8/8/4k3/8/4K3/4P3/8 b - - 0 1', True),
        ('8/8/8/8/4k3/8/4PK2/8 b - - 0 1', True),
    ]
    for fen, want in tests:
        got = kpk(fen)
        print('ok  ' if got == want else 'FAIL', fen, got)
        if got != want:
            sys.exit(1)
