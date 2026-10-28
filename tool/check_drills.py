# Checks every training drill.  Run: python3 tool/check_drills.py
import sys
from perft_mirror import Pos
from mirror_search import in_check
from drills_data import DRILLS
from lessons_data import LESSONS
import tb_kpk as TB
from mirror_structure import concept_targets

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


ids = [d['id'] for d in DRILLS]
check('drill ids are unique', len(ids) == len(set(ids)))
lesson_ids = {l['id'] for l in LESSONS}

for d in DRILLS:
    pos = Pos(d['fen'])
    side = 0 if d['side'] == 'white' else 1
    check(f"{d['id']}: legal position and the game is not over", bool(pos.legal()))
    check(f"{d['id']}: refers to an existing lesson", d.get('lesson') in lesson_ids)
    check(f"{d['id']}: has task, hint and a sensible move limit",
          d['task'] and d['hint'] and 5 <= d['max'] <= 60)
    if d['goal'] == 'find':
        got = concept_targets(d['fen'], d['concept'], d['subject'])
        check(f"{d['id']}: the {d['concept']} answer is {d['answers']}", got == sorted(d['answers']), str(got))
        continue
    if d['goal'] == 'promote':
        # The user's side owns the pawn and the position must be won.
        check(f"{d['id']}: pawn side wins (tablebase)", TB.kpk(d['fen']))
        pawn = 'P' if side == 0 else 'p'
        check(f"{d['id']}: user owns the pawn", pawn in d['fen'].split()[0])
    elif d['goal'] == 'hold':
        check(f"{d['id']}: position is a draw (tablebase)", not TB.kpk(d['fen']))
        pawn = 'p' if side == 0 else 'P'
        check(f"{d['id']}: engine owns the pawn", pawn in d['fen'].split()[0])
    else:  # mate: the user has a queen or rook and the black king is not stalemated/attacked wrongly
        board = d['fen'].split()[0]
        check(f"{d['id']}: user has a queen or rook", any(c in board for c in ('Q', 'R')) if side == 0
              else any(c in board for c in ('q', 'r')))

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
