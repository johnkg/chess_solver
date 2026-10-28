# Independent Python version of lib/engine/structure.dart, used to double-check
# the Level 6 lesson and drill data.  Squares as 'e4'.
def pawns_of(fen):
    """{'white': {(file, rank)}, 'black': {...}} with file 0..7 (a..h), rank 0..7."""
    out = {'white': set(), 'black': set()}
    other = {'white': [], 'black': []}
    rank = 7
    file = 0
    for ch in fen.split()[0]:
        if ch == '/':
            rank -= 1
            file = 0
        elif ch.isdigit():
            file += int(ch)
        else:
            if ch == 'P':
                out['white'].add((file, rank))
            elif ch == 'p':
                out['black'].add((file, rank))
            else:
                other['white' if ch.isupper() else 'black'].append((ch.lower(), file, rank))
            file += 1
    return out, other


def name(f, r):
    return 'abcdefgh'[f] + str(r + 1)


def concept_targets(fen, concept, color):
    pawns, other = pawns_of(fen)
    mine, theirs = pawns[color], pawns['white' if color == 'black' else 'black']
    step = 1 if color == 'white' else -1
    res = []
    if concept == 'passed':
        for f, r in sorted(mine):
            blocked = any(tf in (f - 1, f, f + 1) and (tr - r) * step > 0 for tf, tr in theirs)
            if not blocked:
                res.append(name(f, r))
    elif concept == 'isolated':
        for f, r in sorted(mine):
            if not any(mf in (f - 1, f + 1) for mf, _ in mine):
                res.append(name(f, r))
    elif concept == 'doubled':
        for f, r in sorted(mine):
            if sum(1 for mf, _ in mine if mf == f) >= 2:
                res.append(name(f, r))
    elif concept == 'backward':
        for f, r in sorted(mine):
            side = [(mf, mr) for mf, mr in mine if mf in (f - 1, f + 1)]
            if not side or any((mr - r) * step <= 0 for _, mr in side):
                continue
            stop = r + step
            if not 0 <= stop <= 7:
                continue
            if any(tf in (f - 1, f + 1) and tr == stop + step for tf, tr in theirs):
                res.append(name(f, r))
    elif concept == 'openFile':
        allp = mine | theirs
        for f in range(8):
            if not any(pf == f for pf, _ in allp):
                res += [name(f, r) for r in range(8)]
    elif concept == 'outpost':
        occupied = {}
        for kind, f, r in other['white'] + other['black']:
            pass
        pieces = {}
        for col in ('white', 'black'):
            for kind, f, r in other[col]:
                pieces[(f, r)] = (col, kind)
        for r in range(8):
            rel = r if color == 'white' else 7 - r
            if rel < 4 or rel > 6:
                continue
            for f in range(8):
                if (f, r) in mine or (f, r) in theirs:
                    continue
                if (f, r) in pieces and pieces[(f, r)][0] != color:
                    continue
                if not any(mf in (f - 1, f + 1) and mr == r - step for mf, mr in mine):
                    continue
                if any(tf in (f - 1, f + 1) and (tr - r) * step > 0 for tf, tr in theirs):
                    continue
                res.append(name(f, r))
    return sorted(res)
