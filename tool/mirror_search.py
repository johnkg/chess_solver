# Python mirror of the planned Dart search.dart / eval.dart.
# Purpose: verify the LOGIC (mate solver, alpha-beta, named eval terms)
# before the Dart ports are run on a machine with the Flutter SDK.
import random
from perft_mirror import Pos, mk, pt, pc, sq, P, N, B, R, Q, K, W, Bk

MATE = 100000
VALUE = {P: 100, N: 300, B: 300, R: 500, Q: 900, K: 0}


def in_check(pos):
    k = pos.ksq(pos.turn)
    return k >= 0 and pos.attacked(k, 1 - pos.turn)


def is_capture(pos, mv):
    return pos.sq[mv[1]] != 0 or mv[3] == 4


# ---------- mate-in-N (AND/OR solver) ----------
def mate_in(pos, n):
    """Move that mates within n of the mover's own moves, else None."""
    moves = pos.legal()
    # try checking moves first: they are the most likely mates
    scored = []
    for mv in moves:
        nxt = pos.make(mv)
        scored.append((0 if in_check(nxt) else 1, mv, nxt))
    scored.sort(key=lambda t: t[0])
    for _, mv, nxt in scored:
        replies = nxt.legal()
        if not replies:
            if in_check(nxt):
                return mv
            continue  # stalemate is not mate
        if n > 1 and all(mate_in(nxt.make(r), n - 1) is not None for r in replies):
            return mv
    return None


def find_mate(pos, max_n):
    for n in range(1, max_n + 1):
        mv = mate_in(pos, n)
        if mv is not None:
            return n, mv
    return None


# ---------- eval with named terms (white minus black, centipawns) ----------
CENTER4 = {sq(3, 3), sq(3, 4), sq(4, 3), sq(4, 4)}
EXT_CENTER = {sq(r, f) for r in range(2, 6) for f in range(2, 6)} - CENTER4
HOME_MINORS = {W: {sq(0, 1), sq(0, 2), sq(0, 5), sq(0, 6)},
               Bk: {sq(7, 1), sq(7, 2), sq(7, 5), sq(7, 6)}}


def eval_terms(pos):
    t = {'material': 0, 'center': 0, 'development': 0, 'kingSafety': 0}
    for x in range(64):
        p = pos.sq[x]
        if not p:
            continue
        c, ty = pc(p), pt(p)
        sign = 1 if c == W else -1
        t['material'] += sign * VALUE[ty]
        if ty == P:
            if x in CENTER4:
                t['center'] += sign * 30
            elif x in EXT_CENTER:
                t['center'] += sign * 10
        elif ty in (N, B):
            if x in CENTER4:
                t['center'] += sign * 20
            elif x in EXT_CENTER and ty == N:
                t['center'] += sign * 10
            if x in HOME_MINORS[c]:
                t['development'] -= sign * 15
        elif ty == K:
            r, f = x >> 3, x & 7
            if r == (0 if c == W else 7):
                fr = r + (1 if c == W else -1)
                shield = sum(1 for ff in (f - 1, f, f + 1)
                             if 0 <= ff < 8 and pos.sq[sq(fr, ff)] == mk(P, c))
                t['kingSafety'] += sign * 15 * shield
    return t


def evaluate(pos):
    """Score from the side to move's point of view."""
    total = sum(eval_terms(pos).values())
    return total if pos.turn == W else -total


# ---------- alpha-beta ----------
def order(pos, moves):
    def key(mv):
        v = pos.sq[mv[1]]
        cap = VALUE[pt(v)] * 10 - VALUE[pt(pos.sq[mv[0]])] if v else (900 if mv[3] == 4 else 0)
        return -(cap + (800 if mv[2] else 0))
    return sorted(moves, key=key)


def quiesce(pos, alpha, beta, ply, ev=None):
    ev = ev or evaluate
    stand = ev(pos)
    if stand >= beta:
        return stand
    alpha = max(alpha, stand)
    for mv in order(pos, [m for m in pos.pseudo() if is_capture(pos, m) or m[2]]):
        nxt = pos.make(mv)
        k = nxt.ksq(pos.turn)
        if k >= 0 and nxt.attacked(k, 1 - pos.turn):
            continue
        score = -quiesce(nxt, -beta, -alpha, ply + 1, ev)
        if score >= beta:
            return score
        alpha = max(alpha, score)
    return alpha


def negamax(pos, depth, alpha, beta, ply, quiet=True, ev=None):
    moves = pos.legal()
    if not moves:
        return -MATE + ply if in_check(pos) else 0
    if depth == 0:
        return quiesce(pos, alpha, beta, ply, ev) if quiet else (ev or evaluate)(pos)
    best = -MATE - 1
    for mv in order(pos, moves):
        score = -negamax(pos.make(mv), depth - 1, -beta, -alpha, ply + 1, quiet, ev)
        if score > best:
            best = score
        alpha = max(alpha, score)
        if alpha >= beta:
            break
    return best


def material_eval(pos):
    total = eval_terms(pos)['material']
    return total if pos.turn == W else -total


def best_move(pos, depth):
    best, best_score = None, -MATE - 1
    alpha = -MATE - 1
    for mv in order(pos, pos.legal()):
        score = -negamax(pos.make(mv), depth - 1, -MATE - 1, -alpha, 1)
        if score > best_score:
            best, best_score = mv, score
        alpha = max(alpha, score)
    return best, best_score


def uci(mv):
    n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
    return n(mv[0]) + n(mv[1]) + ('' if not mv[2] else {Q: 'q', R: 'r', B: 'b', N: 'n'}[mv[2]])


def fen_to_pos(fen):
    return Pos(fen)


# ---------- test-position generation ----------
def random_game_positions(rng, max_plies=160):
    """Play random legal moves; return (positions list, ended_in_mate)."""
    pos = Pos("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    seen = [pos]
    for _ in range(max_plies):
        ms = pos.legal()
        if not ms:
            return seen, in_check(pos)
        pos = pos.make(rng.choice(ms))
        seen.append(pos)
    return seen, False
