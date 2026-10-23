# Python mirror of lib/engine/mistakes.dart: "why is my move bad".
from perft_mirror import Pos
from mirror_search import negamax, best_move, in_check, MATE
from mirror_ideas import explain_verified, COLOR, PV
from mirror_san import san

MISTAKE_CP = 150  # a move this much worse than the best is called a mistake


def is_mate_score(score):
    return abs(score) > MATE - 1000


def score_moves(pos, depth):
    """(move, score) for every legal move; score is for the side to move."""
    out = []
    for mv in pos.legal():
        out.append((mv, -negamax(pos.make(mv), depth - 1, -MATE - 1, MATE + 1, 1)))
    return out


def explain_mistake(pos, played, depth=3):
    """None if `played` is fine; otherwise a dict with kind, moves, loss and text."""
    scored = score_moves(pos, depth)
    best, best_score = max(scored, key=lambda t: t[1])
    played_score = dict(scored)[played]
    loss = best_score - played_score
    s = pos.turn
    nxt = pos.make(played)

    kind = None
    if is_mate_score(best_score) and best_score > 0 and not (is_mate_score(played_score) and played_score > 0):
        kind = 'missesMate'
    elif is_mate_score(played_score) and played_score < 0:
        kind = 'allowsMate'
    elif loss >= MISTAKE_CP:
        kind = 'losesMaterial'
    if kind is None:
        return None

    name = san(pos, played)
    best_name = san(pos, best)
    better = explain_verified(pos, best)
    better_text = ' '.join(i['text'] for i in better[:1])
    reply = None
    reason = ''
    if kind == 'missesMate':
        reason = f"{name} misses a forced mate: {best_name}."
    else:
        reply, _ = best_move(nxt, depth - 1)
        reply_name = san(nxt, reply)
        opp = COLOR[1 - s]
        if kind == 'allowsMate':
            reason = f"{name} allows {reply_name}, checkmate."
        else:
            why = explain_verified(nxt, reply)
            detail = why[0]['text'] if why else f"That leaves {opp} clearly better."
            reason = f"{name} is a mistake: {opp} replies {reply_name}. {detail}"
    text = reason
    if kind != 'missesMate':
        text += f" Better was {best_name}."
    if better_text:
        text += f" {better_text}"
    return {'kind': kind, 'played': played, 'best': best, 'reply': reply,
            'loss': loss, 'text': text}
