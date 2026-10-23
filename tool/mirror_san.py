# Python mirror of lib/engine/san.dart: standard algebraic notation.
from perft_mirror import pt, P, N, B, R, Q, K
from mirror_search import in_check
from mirror_ideas import sqname

LETTER = {N: 'N', B: 'B', R: 'R', Q: 'Q', K: 'K'}


def san(pos, mv):
    fr, to, promo, flag = mv
    if flag == 2:
        core = 'O-O'
    elif flag == 3:
        core = 'O-O-O'
    else:
        piece = pos.sq[fr]
        ty = pt(piece)
        capture = pos.sq[to] != 0 or flag == 4
        if ty == P:
            core = ('abcdefgh'[fr & 7] + 'x' if capture else '') + sqname(to)
            if promo:
                core += '=' + LETTER[promo]
        else:
            others = [m for m in pos.legal()
                      if m[1] == to and m[0] != fr and pt(pos.sq[m[0]]) == ty]
            dis = ''
            if others:
                same_file = any((o[0] & 7) == (fr & 7) for o in others)
                same_rank = any((o[0] >> 3) == (fr >> 3) for o in others)
                if not same_file:
                    dis = 'abcdefgh'[fr & 7]
                elif not same_rank:
                    dis = str((fr >> 3) + 1)
                else:
                    dis = sqname(fr)
            core = LETTER[ty] + dis + ('x' if capture else '') + sqname(to)
    nxt = pos.make(mv)
    if in_check(nxt):
        core += '#' if not nxt.legal() else '+'
    return core
