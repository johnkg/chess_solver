# Checks for the Python rater. Run: python3 tool/check_rater.py
import sys
from perft_mirror import Pos
from mirror_rater import rate

fails = 0


def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + (f'  {detail}' if detail else ''))
    if not cond:
        fails += 1


def r(fen):
    return rate(Pos(fen))


# (name, fen, expected solution, expected idea, expected tier, expected mate_in)
cases = [
    ('back-rank mate in 1', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1', 'a1a8', 'backRankMate', 2, 1),
    ("scholar's mate", 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4', 'h5f7', 'checkmate', 1, 1),
    ('smothered mate', '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1', 'g5f7', 'smotheredMate', 3, 1),
    ('free queen', '4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', 'd1d5', 'hangingPiece', 1, 0),
    ('knight fork', '3k3r/8/8/4N3/8/8/8/4K3 w - - 0 1', 'e5f7', 'fork', 2, 0),
]
for name, fen, sol, idea, tier, mate in cases:
    got = r(fen)
    ok = got is not None and got['solution'] == sol and got['idea'] == idea and got['tier'] == tier and got['mate_in'] == mate
    check(name, ok, str(got and (got['solution'], got['idea'], got['tier'], got['mate_in'])))

# a mating move that also skewers is still described as mate, not as a skewer
sk = rate(Pos('r2q1bn1/4p1pr/np1pb2p/p4k2/P2Q3P/2N1BP2/1PP1B1PR/R3K1N1 w - - 0 1'), max_mate=1)
check('mate in 1 that also skewers is rated as a mate', sk is not None and sk['idea'] == 'checkmate' and sk['tier'] == 1,
      str(sk and (sk['idea'], sk['text'])))
# a puzzle whose named idea explains only a fraction of the advantage is rejected
# (Qxa8 wins a rook, but the detectors only credit a small fork)
fr = rate(Pos('rn3bnr/p2pkp1p/b3p1p1/1pp3N1/1P3P1P/P1N1PQ2/R1PP2P1/2B1KBR1 w - - 0 1'), max_mate=1)
check('idea must explain the advantage: Qxa8 case is rejected', fr is None, str(fr and (fr['idea'], fr['text'])))
# several different discovered checks all win the queen: no single answer, so no puzzle
dc = rate(Pos('q3k3/8/8/8/4B3/8/8/4R1K1 w - - 0 1'), max_mate=1)
check('no puzzle when several moves win the queen (Bxa8+, Bd5+, Bc6+)', dc is None, str(dc and dc['solutions']))

# not puzzles
check('start position is not a puzzle', r('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1') is None)
q = r('k7/8/1K6/8/8/8/8/6Q1 w - - 0 1')
check('K+Q mate in 1 lists every mating move or is rejected', q is None or len(q['solutions']) <= 4, str(q and q['solutions']))
check('checkmated side has no puzzle', r('R5k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1') is None)
check('a trade that only wins a defended pawn is not a puzzle', r('4k3/8/2p5/3p4/8/8/8/3RK3 w - - 0 1') is None)

# ladder mate in 2: two rooks, either rook can cut the 7th rank first
ladder = r('7k/8/8/8/8/8/R7/1R4K1 w - - 0 1')
check('ladder mate in 2 is found with its mirror twin', ladder is not None and ladder['mate_in'] == 2 and len(ladder['solutions']) == 2,
      str(ladder and (ladder['solutions'], ladder['tier'])))
if ladder:
    check('mate in 2 sits in tier 4', ladder['tier'] == 4)

print('\nFAILED' if fails else '\nALL OK', fails or '')
sys.exit(1 if fails else 0)
