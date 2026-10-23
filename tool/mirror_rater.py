# Python mirror of lib/engine/rater.dart: rate a position as a puzzle.
#
# A position is a puzzle when exactly one move solves it:
#   - mate puzzle: at most MAX_SOLUTIONS first moves force mate in n (n = shortest, 1..3)
#   - material puzzle: one move clearly beats every other (>= UNIQUE_MARGIN) and
#     search-verified insights name the idea it uses
# Idea = what wins the most material (or the mate pattern); tier = that idea's difficulty.
from mirror_search import mate_in, find_mate, in_check
from mirror_ideas import explain_verified
from mirror_mistakes import score_moves
from mirror_san import san

UNIQUE_MARGIN = 200  # centipawns the solution must beat the runner-up by
EXPLAIN_SLACK = 100  # the named idea must account for the advantage to within this much
MAX_MATE = 3
MAX_SOLUTIONS = 4  # ladder mates often have a mirror-image twin

# idea -> difficulty tier (1 easiest)
TIER = {
    'hangingPiece': 1, 'checkmate': 1,
    'backRankMate': 2, 'fork': 2, 'skewer': 2,
    'removingDefender': 3, 'discoveredAttack': 3, 'doubleCheck': 3, 'smotheredMate': 3,
}
MATE_TIER = {2: 4, 3: 5}
# ties inside one tier go to the more specific idea
PRIORITY = ['smotheredMate', 'backRankMate', 'doubleCheck', 'discoveredAttack',
            'removingDefender', 'skewer', 'fork', 'checkmate', 'hangingPiece']


def uci_of(m):
    n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
    return n(m[0]) + n(m[1]) + ('' if not m[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[m[2]])


def is_mate_move(pos, mv, n):
    """Does mv force mate within n of the mover's own moves?"""
    nxt = pos.make(mv)
    replies = nxt.legal()
    if not replies:
        return in_check(nxt)
    if n == 1:
        return False
    return all(mate_in(nxt.make(r), n - 1) is not None for r in replies)


MATE_IDEAS = ('smotheredMate', 'backRankMate', 'checkmate')


def pick_idea(insights, mate=False):
    """The idea that explains the solution.
    mate=True (a mate in 1): the most specific mate pattern.
    otherwise: the idea that wins the most material; ties go to the harder
    tier, then to the more specific idea. (So Qxa8 winning a free rook is a
    free piece, not a 'fork' of two pawns it also happens to attack.)"""
    if mate:
        cands = [i for i in insights if i['idea'] in MATE_IDEAS]
        return min(cands, key=lambda i: PRIORITY.index(i['idea'])) if cands else None
    cands = [i for i in insights if i['idea'] in TIER and i['idea'] not in MATE_IDEAS]
    if not cands:
        return None
    return max(cands, key=lambda i: (i['gain'], TIER[i['idea']], -PRIORITY.index(i['idea'])))


def rate(pos, depth=3, max_mate=MAX_MATE):
    """None if pos is not a clean one-solution puzzle, else a dict:
    {solution, solutions, san, idea, tier, mate_in, text}.
    max_mate bounds the forced-mate search (a deeper mate is then rated as a
    material puzzle, if it is one)."""
    if not pos.legal():
        return None

    mate = find_mate(pos, max_mate)
    if mate is not None:
        n = mate[0]
        sols = sorted((uci_of(m), m) for m in pos.legal() if is_mate_move(pos, m, n))
        if not 1 <= len(sols) <= MAX_SOLUTIONS:
            return None
        names = [u for u, _ in sols]
        sol = sols[0][1]
        if n == 1:
            ins = pick_idea(explain_verified(pos, sol), mate=True)
            idea = ins['idea'] if ins else 'checkmate'
            text = ins['text'] if ins else 'Checkmate.'
            return {'solution': names[0], 'solutions': names, 'san': san(pos, sol), 'idea': idea,
                    'tier': TIER[idea], 'mate_in': 1, 'text': text}
        return {'solution': names[0], 'solutions': names, 'san': san(pos, sol), 'idea': None,
                'tier': MATE_TIER[n], 'mate_in': n,
                'text': f"{san(pos, sol)} forces checkmate in {n}: every reply still runs into mate."}

    scored = sorted(score_moves(pos, depth), key=lambda t: -t[1])
    if len(scored) < 2:
        return None
    gap = scored[0][1] - scored[1][1]
    if gap < UNIQUE_MARGIN:
        return None
    best = scored[0][0]
    ins = pick_idea(explain_verified(pos, best))
    if ins is None or ins['gain'] <= 0 or ins['gain'] + EXPLAIN_SLACK < gap:
        return None  # no idea, or the idea explains only a fraction of why the move wins
    return {'solution': uci_of(best), 'solutions': [uci_of(best)], 'san': san(pos, best), 'idea': ins['idea'],
            'tier': TIER[ins['idea']], 'mate_in': 0, 'text': ins['text']}
