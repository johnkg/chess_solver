# Checks every lesson example against the Python engine. Run: python3 tool/check_lessons.py
import sys
from perft_mirror import Pos
from mirror_ideas import explain, explain_verified, MATERIAL_IDEAS, sqname
from mirror_search import in_check
from lessons_data import LESSONS
from drills_data import DRILLS
import tb_kpk as TB
from mirror_structure import concept_targets

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
drill_ids = {d['id'] for d in DRILLS}
check('every lesson drill exists and every plan lesson has a note',
      all(l.get('drill', next(iter(drill_ids))) in drill_ids and (l['kind'] != 'plan' or l.get('note')) for l in LESSONS))

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
    elif kind == 'concept':
        got = concept_targets(l['fen'], l['concept'], l['side'])
        check(f"{l['id']}: the {l['concept']} squares are {l['targets']}", got == sorted(l['targets']), str(got))
    elif kind == 'line':
        from famous import replay
        sans = [x for _, _, x in replay(' '.join(l['line']))]
        check(f"{l['id']}: every move of the line is legal, one note per move",
              sans == l['line'] and len(l['notes']) == len(l['line']) and l['side'] in ('white', 'black'))
    elif kind == 'plan':
        lid = l['id']
        mv = [m for m in pos.legal() if uci_of(m) == l['move']]
        if not mv:
            check(f"{lid}: move {l['move']} is legal", False)
            continue
        if lid in ('eg-kq', 'eg-kr'):
            after = pos.make(mv[0])
            check(f"{lid}: {l['move']} is checkmate", in_check(after) and not after.legal())
        else:
            fen = l['fen']
            wins_after = lambda f, u: TB.kpk_after(f, u)
            others = [uci_of(m) for m in pos.legal()]
            result = {u: wins_after(fen, u) for u in others}
            if lid == 'eg-opposition':
                check(f"{lid}: {l['move']} wins and nothing else does",
                      result[l['move']] is True and sum(1 for v in result.values() if v) == 1, str(result))
            elif lid == 'eg-keysq':
                other = fen.replace(' w ', ' b ')
                check(f"{lid}: wins with either side to move and {l['move']} keeps it",
                      TB.kpk(fen) and TB.kpk(other) and result[l['move']] is True)
            elif lid == 'eg-square':
                other = fen.replace(' w ', ' b ')
                check(f"{lid}: {l['move']} wins; with Black to move it is a draw",
                      result[l['move']] is True and TB.kpk(fen) and not TB.kpk(other))
            elif lid == 'eg-rookpawn':
                check(f"{lid}: a draw whatever White plays",
                      not TB.kpk(fen) and not any(result.values()), str(result))
            else:
                check(f"{lid}: no check defined for this plan lesson", False)
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
