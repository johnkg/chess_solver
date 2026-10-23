# Checks every lesson example against the Python engine. Run: python3 tool/check_lessons.py
import sys
from perft_mirror import Pos
from mirror_ideas import explain, explain_verified, MATERIAL_IDEAS, sqname
from mirror_search import in_check
from lessons_data import LESSONS

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


def uci_of(m):
    n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
    return n(m[0]) + n(m[1]) + ('' if not m[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[m[2]])


ids = [l['id'] for l in LESSONS]
check('lesson ids are unique', len(ids) == len(set(ids)))
check('every lesson has title, tagline, why and 3 spotting tips',
      all(l['title'] and l['tagline'] and l['why'] and len(l['spot']) == 3 for l in LESSONS))

for l in LESSONS:
    pos = Pos(l['fen'])
    kind = l['kind']
    if kind == 'moves':
        sq_ = l['square']
        frm = (int(sq_[1]) - 1) * 8 + ord(sq_[0]) - 97
        got = sorted({sqname(m[1]) for m in pos.legal() if m[0] == frm})
        check(f"{l['id']}: moves from {sq_}", got == sorted(l['targets']), f'{got}')
    elif kind == 'status':
        st = l['status']
        legal = pos.legal()
        if st == 'check':
            ok = in_check(pos) and bool(legal)
        elif st == 'checkmate':
            ok = in_check(pos) and not legal
        else:
            ok = not in_check(pos) and not legal
        check(f"{l['id']}: is {st}", ok)
    else:
        mv = [m for m in pos.legal() if uci_of(m) == l['move']]
        if not mv:
            check(f"{l['id']}: move {l['move']} is legal", False)
            continue
        f = explain_verified if l['idea'] in MATERIAL_IDEAS else explain
        got = {i['idea'] for i in f(pos, mv[0])}
        check(f"{l['id']}: {l['move']} shows {l['idea']}", l['idea'] in got, str(sorted(got)))

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
