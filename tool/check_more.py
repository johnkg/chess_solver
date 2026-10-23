# Checks for: smothered mate, double check, discovered attack, removing the
# defender, and SAN. Run: python3 tool/check_more.py
import sys
from perft_mirror import Pos
from mirror_ideas import explain, explain_verified
from mirror_san import san

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


def uci_of(m):
    n = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
    return n(m[0]) + n(m[1]) + ('' if not m[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[m[2]])


def mv_of(pos, uci):
    for m in pos.legal():
        if uci_of(m) == uci:
            return m
    raise ValueError(uci)


def ideas(fen, uci, verified=False):
    pos = Pos(fen)
    f = explain_verified if verified else explain
    return {i['idea']: i for i in f(pos, mv_of(pos, uci))}


# ---- ideas: (name, fen, move, must have, must not have)
cases = [
    ('smothered mate', '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1', 'g5f7', 'smotheredMate', 'checkmate'),
    ('double check (Nd6+ uncovering Re1)', '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4d6', 'doubleCheck', None),
    ('discovered check also reported', '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4d6', 'discoveredAttack', None),
    ('discovered check wins the queen', '4k3/8/8/3q4/4B3/8/8/4R1K1 w - - 0 1', 'e4d5', 'discoveredAttack', None),
    ('no double check for a plain check', '4k3/8/8/8/8/8/8/4R1K1 w - - 0 1', 'e1e7', None, 'doubleCheck'),
    ('discovered attack with check wins the queen', '4k3/3q4/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4f6', 'discoveredAttack', None),
    ('removing the defender: Bxc6 then Nxe5', '2bqkb1r/p1pp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQ - 0 1', 'b5c6', 'removingDefender', 'hangingPiece'),
    ('a quiet move uncovering nothing', '4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1', 'g1h1', None, 'discoveredAttack'),
]
for name, fen, uci, want, notwant in cases:
    got = ideas(fen, uci)
    ok = (want is None or want in got) and (notwant is None or notwant not in got)
    check(name, ok, str(sorted(got)))

# ---- verification keeps the true ones and drops the shaky one
for name, fen, uci, want in (
        ('keeps discovered attack on queen', '4k3/3q4/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4f6', 'discoveredAttack'),
        ('keeps removing the defender', '2bqkb1r/p1pp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQ - 0 1', 'b5c6', 'removingDefender')):
    check('verified: ' + name, want in ideas(fen, uci, verified=True), str(sorted(ideas(fen, uci, verified=True))))
raw = ideas('6k1/4r3/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4f6')
ver = ideas('6k1/4r3/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4f6', verified=True)
check('verification drops a discovered attack the king can parry (Kf8 defends Re7)',
      'discoveredAttack' in raw and 'discoveredAttack' not in ver, f'raw={sorted(raw)} verified={sorted(ver)}')

# ---- text sanity
t = ideas('6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1', 'g5f7')['smotheredMate']['text']
check('smothered text', 'h8' in t and 'f7' in t and 'boxed in' in t, t)
t = ideas('4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1', 'e4d6')['doubleCheck']['text']
check('double check text', all(w in t for w in ('rook', 'e1', 'knight', 'd6', 'e8')), t)

# ---- SAN
def play(fen, sans):
    pos = Pos(fen)
    got = []
    for target in sans:
        match = [m for m in pos.legal() if san(pos, m) == target]
        if len(match) != 1:
            return got + ['??' + target], pos
        got.append(san(pos, match[0]))
        pos = pos.make(match[0])
    return got, pos


start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
line = ['e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#']
got, _ = play(start, line)
check("SAN replays scholar's mate", got == line, str(got))
spec = [
    ('castle both ways', 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1', ['O-O', 'O-O-O']),
    ('knight file disambiguation', '4k3/8/8/8/8/2N3N1/8/4K3 w - - 0 1', ['Nce4', 'Nge4']),
    ('rook rank disambiguation', '4k3/R7/8/8/8/8/R7/4K3 w - - 0 1', ['R7a4', 'R2a4']),
    ('promotion with check', '7k/P7/8/8/8/8/8/K7 w - - 0 1', ['a8=Q+', 'a8=N']),
    ('pawn capture', '4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1', ['exd5', 'e5']),
    ('en passant', '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1', ['exd6', 'e6']),
]
for name, fen, sans in spec:
    pos = Pos(fen)
    produced = {san(pos, m) for m in pos.legal()}
    check('SAN ' + name, all(s in produced for s in sans), str(sorted(produced)))
# every legal move of a busy position gets a unique SAN
kiwi = Pos('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1')
names = [san(kiwi, m) for m in kiwi.legal()]
check('SAN is unique for all 48 kiwipete moves', len(names) == 48 and len(set(names)) == 48, str(len(set(names))))

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
