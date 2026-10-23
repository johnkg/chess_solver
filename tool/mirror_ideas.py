# Python mirror of the planned Dart idea detectors + explainer.
# Verifies the LOGIC without a Dart SDK. Keep in sync with lib/engine/ideas/.
from perft_mirror import (Pos, mk, pt, pc, sq, P, N, B, R, Q, K, W, Bk,
                          KN, KG, BD, RD)
from mirror_search import in_check, eval_terms

# value used for attack/defence reasoning; the king is "priceless"
PV = {P: 100, N: 300, B: 300, R: 500, Q: 900, K: 1000}
NAMES = {P: 'pawn', N: 'knight', B: 'bishop', R: 'rook', Q: 'queen', K: 'king'}
COLOR = {W: 'White', Bk: 'Black'}


def sqname(x):
    return 'abcdefgh'[x & 7] + str((x >> 3) + 1)


def piece_name(p):
    return NAMES[pt(p)]


# ---------------------------------------------------------------- attacks
def attackers_of(pos, target, by):
    """Squares of colour `by` pieces attacking `target` (pins ignored)."""
    out = []
    r, f = target >> 3, target & 7
    pr = r - 1 if by == W else r + 1
    if 0 <= pr < 8:
        for df in (-1, 1):
            ff = f + df
            if 0 <= ff < 8 and pos.sq[sq(pr, ff)] == mk(P, by):
                out.append(sq(pr, ff))
    for steps, ty in ((KN, N), (KG, K)):
        for d in steps:
            nr, nf = r + d[0], f + d[1]
            if 0 <= nr < 8 and 0 <= nf < 8 and pos.sq[sq(nr, nf)] == mk(ty, by):
                out.append(sq(nr, nf))
    for dirs, ty in ((BD, B), (RD, R)):
        for d in dirs:
            nr, nf = r + d[0], f + d[1]
            while 0 <= nr < 8 and 0 <= nf < 8:
                p = pos.sq[sq(nr, nf)]
                if p:
                    if p == mk(ty, by) or p == mk(Q, by):
                        out.append(sq(nr, nf))
                    break
                nr += d[0]
                nf += d[1]
    return out


def attacked_squares(pos, x):
    """Squares the piece on x attacks (including squares holding any piece)."""
    p = pos.sq[x]
    ty, c = pt(p), pc(p)
    r, f = x >> 3, x & 7
    out = []
    if ty == P:
        nr = r + (1 if c == W else -1)
        for df in (-1, 1):
            if 0 <= nr < 8 and 0 <= f + df < 8:
                out.append(sq(nr, f + df))
    elif ty in (N, K):
        for d in (KN if ty == N else KG):
            nr, nf = r + d[0], f + d[1]
            if 0 <= nr < 8 and 0 <= nf < 8:
                out.append(sq(nr, nf))
    else:
        dirs = BD if ty == B else RD if ty == R else BD + RD
        for d in dirs:
            nr, nf = r + d[0], f + d[1]
            while 0 <= nr < 8 and 0 <= nf < 8:
                out.append(sq(nr, nf))
                if pos.sq[sq(nr, nf)]:
                    break
                nr += d[0]
                nf += d[1]
    return out


def is_safe(pos, x, color):
    """Can the piece of `color` on x be taken at a profit?"""
    p = pos.sq[x]
    atk = attackers_of(pos, x, 1 - color)
    if not atk:
        return True
    if not attackers_of(pos, x, color):
        return False  # attacked and undefended
    vals = [PV[pt(pos.sq[a])] for a in atk if pt(pos.sq[a]) != K]
    return not vals or min(vals) >= PV[pt(p)]


def see_capture(pos, mv):
    """Net material (centipawns) the mover wins by the capture sequence on mv.to.
    Standard swap algorithm; x-rays are found because the board is mutated."""
    fr, to = mv[0], mv[1]
    victim = pos.sq[to]
    vv = PV[pt(victim)] if victim else 100  # en passant takes a pawn
    tmp = Pos.__new__(Pos)
    tmp.sq = pos.sq[:]
    mover = tmp.sq[fr]
    tmp.sq[fr] = 0
    tmp.sq[to] = mover
    gain = [vv]
    piece = PV[pt(mover)]
    side = 1 - pos.turn
    while True:
        atk = attackers_of(tmp, to, side)
        if not atk:
            break
        a = min(atk, key=lambda x: PV[pt(tmp.sq[x])])
        if pt(tmp.sq[a]) == K and attackers_of(tmp, to, 1 - side):
            break  # king may not capture onto a defended square
        gain.append(piece - gain[-1])
        piece = PV[pt(tmp.sq[a])]
        tmp.sq[to] = tmp.sq[a]
        tmp.sq[a] = 0
        side = 1 - side
    while len(gain) > 1:
        g = gain.pop()
        gain[-1] = -max(-gain[-1], g)
    return gain[0]


# ---------------------------------------------------------------- insights
def insight(idea, mv, squares, gain, text, level):
    return {'idea': idea, 'move': mv, 'squares': squares, 'gain': gain,
            'text': text, 'level': level}


def mover_desc(pos, mv):
    p = pos.sq[mv[0]]
    return COLOR[pc(p)], piece_name(p)


def d_mate(pos, mv, nxt):
    if nxt.legal() or not in_check(nxt):
        return []
    s = pos.turn
    who, piece = mover_desc(pos, mv)
    k = nxt.ksq(1 - s)
    home = 7 if s == W else 0
    mover_after = nxt.sq[mv[1]]
    if pt(mover_after) == N:
        around = [sq((k >> 3) + d[0], (k & 7) + d[1]) for d in KG
                  if 0 <= (k >> 3) + d[0] < 8 and 0 <= (k & 7) + d[1] < 8]
        if all(nxt.sq[c] and pc(nxt.sq[c]) == 1 - s for c in around):
            return [insight('smotheredMate', mv, [mv[1], k] + around, 100000,
                            f"Smothered mate. The {COLOR[1-s].lower()} king on {sqname(k)} is boxed in by its own pieces, "
                            f"so the knight on {sqname(mv[1])} gives check and nothing can capture it or help the king.",
                            4)]
    if (k >> 3 == home and mv[1] >> 3 == home and pt(mover_after) in (R, Q)):
        front = home + (-1 if s == W else 1)
        cells = [sq(front, ff) for ff in range((k & 7) - 1, (k & 7) + 2) if 0 <= ff < 8]
        if all(nxt.sq[c] and pc(nxt.sq[c]) == 1 - s for c in cells):
            names = ', '.join(sqname(c) for c in cells)
            return [insight('backRankMate', mv, [mv[1], k] + cells, 100000,
                            f"Checkmate. The {COLOR[1-s].lower()} king on {sqname(k)} is trapped on its back rank by its own "
                            f"pieces on {names}, and the {piece_name(mover_after)} on {sqname(mv[1])} attacks it along the rank.",
                            4)]
    return [insight('checkmate', mv, [mv[1], k], 100000,
                    f"Checkmate. The {piece} to {sqname(mv[1])} attacks the king on {sqname(k)} and it has no safe square "
                    f"and nothing can block or capture.", 4)]


def d_capture(pos, mv, nxt):
    if mv[2]:
        return []
    victim = pos.sq[mv[1]]
    if not victim and mv[3] != 4:
        return []
    if victim and pt(victim) == K:
        return []
    s = pos.turn
    net = see_capture(pos, mv)
    if net <= 0:
        return []
    who, piece = mover_desc(pos, mv)
    vname = piece_name(victim) if victim else 'pawn'
    free = not attackers_of(nxt, mv[1], 1 - s)
    if free:
        text = (f"{piece.capitalize()} takes the {vname} on {sqname(mv[1])}. Nothing can recapture, "
                f"so {who} wins a free {vname}.")
    else:
        text = (f"{piece.capitalize()} takes the {vname} on {sqname(mv[1])}. It can be recaptured, but the "
                f"{vname} is worth more than the {piece}, so {who} still comes out ahead.")
    return [insight('hangingPiece', mv, [mv[0], mv[1]], net, text, 3)]


def d_fork(pos, mv, nxt):
    s = pos.turn
    to = mv[1]
    forker = nxt.sq[to]
    if not forker or not is_safe(nxt, to, s):
        return []
    king_attacked = False
    gains = []
    targets = []
    for t in attacked_squares(nxt, to):
        p = nxt.sq[t]
        if not p or pc(p) == s:
            continue
        if attackers_of(pos, t, s):
            continue  # already attacked before this move: not a new threat
        if pt(p) == K:
            king_attacked = True
            targets.append(t)
            continue
        defenders = attackers_of(nxt, t, 1 - s)
        g = PV[pt(p)] if not defenders else PV[pt(p)] - PV[pt(forker)]
        if g > 0:
            gains.append(g)
            targets.append(t)
    gains.sort(reverse=True)
    if king_attacked and len(gains) >= 1:
        claim = gains[0]
    elif not king_attacked and len(gains) >= 2:
        claim = gains[1]
    else:
        return []
    who, piece = mover_desc(pos, mv)
    desc = [f"the {piece_name(nxt.sq[t])} on {sqname(t)}" for t in targets]
    listed = ' and '.join(desc) if len(desc) <= 2 else ', '.join(desc[:-1]) + ' and ' + desc[-1]
    follow = (f"{COLOR[1-s]} must answer the check, so {who} then wins the other piece."
              if king_attacked else f"{COLOR[1-s]} can only save one of them.")
    text = f"{piece.capitalize()} to {sqname(to)} forks {listed}. {follow}"
    return [insight('fork', mv, [to] + targets, claim, text, 4)]


def lines_of(pos, color):
    """All (slider, front, back) triples where a `color` slider sees two enemy
    pieces in a row along one line."""
    out = []
    for x in range(64):
        p = pos.sq[x]
        if not p or pc(p) != color or pt(p) not in (B, R, Q):
            continue
        ty = pt(p)
        dirs = BD if ty == B else RD if ty == R else BD + RD
        r, f = x >> 3, x & 7
        for d in dirs:
            nr, nf = r + d[0], f + d[1]
            front = None
            while 0 <= nr < 8 and 0 <= nf < 8:
                y = sq(nr, nf)
                q = pos.sq[y]
                if q:
                    if pc(q) == color:
                        break
                    if front is None:
                        front = y
                    else:
                        out.append((x, front, y))
                        break
                nr += d[0]
                nf += d[1]
    return out


def d_lines(pos, mv, nxt):
    s = pos.turn
    before = set(lines_of(pos, s))
    out = []
    for (x, front, back) in lines_of(nxt, s):
        if (x, front, back) in before or not is_safe(nxt, x, s):
            continue
        fv, bv = PV[pt(nxt.sq[front])], PV[pt(nxt.sq[back])]
        slider = piece_name(nxt.sq[x])
        who = COLOR[s]
        fn, bn = piece_name(nxt.sq[front]), piece_name(nxt.sq[back])
        if bv > fv:  # pin
            if pt(nxt.sq[back]) == K:
                text = (f"The {slider} on {sqname(x)} pins the {fn} on {sqname(front)} to the king on {sqname(back)}: "
                        f"the {fn} cannot move without exposing the king.")
                out.append(insight('pin', mv, [x, front, back], 0, text, 4))
            else:
                text = (f"The {slider} on {sqname(x)} pins the {fn} on {sqname(front)} to the {bn} on {sqname(back)}: "
                        f"if the {fn} moves, {who} wins the {bn}.")
                out.append(insight('pin', mv, [x, front, back], 0, text, 4))
        elif fv > bv:  # skewer
            front_defended = attackers_of(nxt, front, 1 - s)
            forced = pt(nxt.sq[front]) == K or not front_defended or fv > PV[pt(nxt.sq[x])]
            if not forced:
                continue  # the front piece can simply stay put
            defenders = attackers_of(nxt, back, 1 - s)
            gain = bv if not defenders else bv - PV[pt(nxt.sq[x])]
            if gain <= 0:
                continue
            if pt(nxt.sq[front]) == K:
                text = (f"The {slider} on {sqname(x)} skewers the king on {sqname(front)}: the king must move, "
                        f"and then {who} takes the {bn} on {sqname(back)}.")
            else:
                text = (f"The {slider} on {sqname(x)} skewers the {fn} on {sqname(front)}: it must move, "
                        f"and then {who} takes the {bn} on {sqname(back)}.")
            out.append(insight('skewer', mv, [x, front, back], gain, text, 4))
    return out


def d_positional(pos, mv, nxt):
    s = pos.turn
    sign = 1 if s == W else -1
    who, piece = mover_desc(pos, mv)
    if mv[3] in (2, 3):
        side = 'kingside' if mv[3] == 2 else 'queenside'
        return [insight('castling', mv, [mv[0], mv[1]], 0,
                        f"{who} castles {side}: the king gets behind its pawns and the rook joins the game.", 3)]
    a, b = eval_terms(pos), eval_terms(nxt)
    dev = sign * (b['development'] - a['development'])
    cen = sign * (b['center'] - a['center'])
    if dev > 0:
        return [insight('development', mv, [mv[0], mv[1]], 0,
                        f"Develops the {piece} from {sqname(mv[0])} to {sqname(mv[1])}: pieces in play beat pieces at home.", 3)]
    if cen > 0:
        return [insight('center', mv, [mv[0], mv[1]], 0,
                        f"The {piece} to {sqname(mv[1])} fights for the center, where pieces control the most squares.", 3)]
    return []


def mover_gains(pos, nxt, to, s):
    """Gains (centipawns) of targets the piece now on `to` newly attacks."""
    forker = nxt.sq[to]
    gains = []
    for t in attacked_squares(nxt, to):
        p = nxt.sq[t]
        if not p or pc(p) == s or pt(p) == K:
            continue
        if attackers_of(pos, t, s):
            continue
        defenders = attackers_of(nxt, t, 1 - s)
        g = PV[pt(p)] if not defenders else PV[pt(p)] - PV[pt(forker)]
        if g > 0:
            gains.append(g)
    return sorted(gains, reverse=True)


def d_double_check(pos, mv, nxt):
    if not in_check(nxt) or not nxt.legal():
        return []  # not check, or checkmate (the mate detector covers it)
    s = pos.turn
    k = nxt.ksq(1 - s)
    atk = attackers_of(nxt, k, s)
    if len(atk) < 2:
        return []
    a, b = atk[0], atk[1]
    text = (f"Double check: the {piece_name(nxt.sq[a])} on {sqname(a)} and the {piece_name(nxt.sq[b])} on {sqname(b)} "
            f"both attack the king on {sqname(k)}. Two checks cannot be blocked or captured at once, so the king must move.")
    return [insight('doubleCheck', mv, [a, b, k], 0, text, 4)]


def d_discovered(pos, mv, nxt):
    if mv[3] in (2, 3):
        return []
    s = pos.turn
    to = mv[1]
    disc = []
    for x in range(64):
        p = nxt.sq[x]
        if x == to or not p or pc(p) != s or pt(p) not in (B, R, Q):
            continue
        before = set(attacked_squares(pos, x))
        for t in attacked_squares(nxt, x):
            q = nxt.sq[t]
            if not q or pc(q) == s or t in before:
                continue
            if pt(q) == K:
                disc.append((x, t, None))
            else:
                defenders = attackers_of(nxt, t, 1 - s)
                g = PV[pt(q)] if not defenders else PV[pt(q)] - PV[pt(p)]
                if g > 0:
                    disc.append((x, t, g))
    if not disc:
        return []
    who, piece = mover_desc(pos, mv)
    opp = COLOR[1 - s]
    net = 0
    if (pos.sq[to] or mv[3] == 4) and not mv[2]:
        net = max(net, see_capture(pos, mv))
    own = mover_gains(pos, nxt, to, s)
    if own:
        net = max(net, own[0])
    checks = [d for d in disc if d[2] is None]
    if checks:
        x, t, _ = checks[0]
        slider = piece_name(nxt.sq[x])
        tail = (f"so the {piece} is free to win material on {sqname(to)} at the same time." if net > 0
                else f"so {who} gains a tempo.")
        text = (f"Moving the {piece} uncovers the {slider} on {sqname(x)}, which checks the king on {sqname(t)}. "
                f"{opp} must answer the check, {tail}")
        return [insight('discoveredAttack', mv, [x, t, to], max(net, 0), text, 4)]
    x, t, g = max(disc, key=lambda d: d[2])
    slider = piece_name(nxt.sq[x])
    target = f"{piece_name(nxt.sq[t])} on {sqname(t)}"
    if in_check(nxt):
        text = (f"Moving the {piece} gives check and uncovers the {slider} on {sqname(x)}, which attacks the {target}. "
                f"{opp} must answer the check, so there is no time to save it.")
        return [insight('discoveredAttack', mv, [x, t, to], g, text, 4)]
    if net <= 0:
        return []
    text = (f"Moving the {piece} uncovers the {slider} on {sqname(x)}, which now attacks the {target}, "
            f"while the {piece} makes a threat of its own. {opp} cannot meet both.")
    return [insight('discoveredAttack', mv, [x, t, to], min(g, net), text, 4)]


def d_remove_defender(pos, mv, nxt):
    victim = pos.sq[mv[1]]
    if not victim or mv[2] or pt(victim) == K:
        return []
    s = pos.turn
    d_sq = mv[1]
    cap = see_capture(pos, mv)
    if cap > 0:
        return []  # a plain win: d_capture explains it
    best = None
    for t_sq in range(64):
        t = pos.sq[t_sq]
        if not t or pc(t) == s or pt(t) == K or t_sq == d_sq:
            continue
        if not attackers_of(pos, t_sq, s):
            continue  # was not under attack before
        if d_sq not in attackers_of(pos, t_sq, 1 - s):
            continue  # the captured piece was not defending it
        mine = attackers_of(nxt, t_sq, s)
        if not mine:
            continue
        theirs = attackers_of(nxt, t_sq, 1 - s)
        g = PV[pt(t)] if not theirs else PV[pt(t)] - min(PV[pt(nxt.sq[a])] for a in mine)
        g += cap  # cap <= 0: what the capture itself costs
        if g > 0 and (best is None or g > best[1]):
            best = (t_sq, g)
    if not best:
        return []
    who, piece = mover_desc(pos, mv)
    t_sq, g = best
    text = (f"{piece.capitalize()} takes the {piece_name(victim)} on {sqname(d_sq)}. That piece was defending the "
            f"{piece_name(pos.sq[t_sq])} on {sqname(t_sq)}, which is now short of protection, so {who} threatens to win it.")
    return [insight('removingDefender', mv, [mv[0], d_sq, t_sq], g, text, 4)]


DETECTORS = (d_mate, d_double_check, d_capture, d_fork, d_discovered, d_remove_defender, d_lines)


def explain(pos, mv):
    nxt = pos.make(mv)
    out = []
    for det in DETECTORS:
        out += det(pos, mv, nxt)
    if not out:
        out += d_positional(pos, mv, nxt)
    return out



# ---------------------------------------------------------------- verification
from mirror_search import negamax, material_eval, MATE  # noqa: E402

MATERIAL_IDEAS = ('hangingPiece', 'fork', 'skewer', 'discoveredAttack', 'removingDefender')


def pass_turn(pos):
    p = Pos.__new__(Pos)
    p.sq, p.cast, p.ep, p.turn = pos.sq[:], pos.cast, -1, 1 - pos.turn
    return p


def material_outcome(pos_after_move, depth=2):
    """Mover's material result with the opponent to move (depth plies + quiescence)."""
    return -negamax(pos_after_move, depth, -MATE - 1, MATE + 1, 1, True, material_eval)


def margin(pos, mv, depth=2):
    """Material the move gains compared with passing the turn."""
    base = material_outcome(pass_turn(pos), depth)
    return material_outcome(pos.make(mv), depth) - base


def explain_verified(pos, mv):
    """Like explain(), but material claims (free piece, fork, skewer) are kept
    only if a 2-ply material search confirms the claimed gain."""
    out = []
    for ins in explain(pos, mv):
        if ins['idea'] in MATERIAL_IDEAS and ins['gain'] > 0:
            if in_check(pos) or margin(pos, mv) < ins['gain']:
                continue
            ins = dict(ins, verified=True)
        out.append(ins)
    if not any(i['idea'] in MATERIAL_IDEAS for i in out) and not out:
        out += d_positional(pos, mv, pos.make(mv))
    return out
