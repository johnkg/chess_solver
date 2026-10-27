# Famous and professional games. Only the move lists are typed in; positions are
# replayed with the Python engine, so a mistyped move fails loudly (no legal match).
# Used by lessons_data.py (Level 7 lessons) and curate.py (puzzles).
import re

from perft_mirror import Pos
from mirror_games import to_fen
from mirror_san import san

START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'


def _bare(s):
    return s.rstrip('+#!?')


def replay(movetext):
    """Yield (position before the move, move tuple, SAN) for every ply."""
    pos = Pos(START)
    for tok in movetext.split():
        tok = re.sub(r'^\d+\.', '', tok)
        if not tok:
            continue
        for mv in pos.legal():
            if _bare(san(pos, mv)) == _bare(tok):
                yield pos, mv, san(pos, mv)
                pos = pos.make(mv)
                break
        else:
            raise ValueError(f'illegal or unknown move {tok!r} after {to_fen(pos)}')


def before(movetext, key, nth=1):
    """FEN and UCI of the nth occurrence of SAN `key` in the game."""
    n = 0
    for pos, mv, s in replay(movetext):
        if _bare(s) == _bare(key):
            n += 1
            if n == nth:
                f = lambda x: 'abcdefgh'[x & 7] + str((x >> 3) + 1)
                return to_fen(pos), f(mv[0]) + f(mv[1]) + ('' if not mv[2] else {5: 'q', 4: 'r', 3: 'b', 2: 'n'}[mv[2]])
    raise ValueError(f'{key!r} not found in game')


GAMES = [
    dict(id='legal', white='Saint Brie', black='Legal', place='Paris', year=1750,
         moves='1.e4 e5 2.Nf3 d6 3.Bc4 Bg4 4.Nc3 g6 5.Nxe5 Bxd1 6.Bxf7+ Ke7 7.Nd5#',
         key='Nd5#'),
    dict(id='opera', white='Paul Morphy', black='Duke of Brunswick and Count Isouard', place='Paris Opera', year=1858,
         moves='1.e4 e5 2.Nf3 d6 3.d4 Bg4 4.dxe5 Bxf3 5.Qxf3 dxe5 6.Bc4 Nf6 7.Qb3 Qe7 8.Nc3 c6 9.Bg5 b5 '
               '10.Nxb5 cxb5 11.Bxb5+ Nbd7 12.O-O-O Rd8 13.Rxd7 Rxd7 14.Rd1 Qe6 15.Bxd7+ Nxd7 16.Qb8+ Nxb8 17.Rd8#',
         key='Qb8+'),
    dict(id='immortal', white='Adolf Anderssen', black='Lionel Kieseritzky', place='London', year=1851,
         moves='1.e4 e5 2.f4 exf4 3.Bc4 Qh4+ 4.Kf1 b5 5.Bxb5 Nf6 6.Nf3 Qh6 7.d3 Nh5 8.Nh4 Qg5 9.Nf5 c6 10.g4 Nf6 '
               '11.Rg1 cxb5 12.h4 Qg6 13.h5 Qg5 14.Qf3 Ng8 15.Bxf4 Qf6 16.Nc3 Bc5 17.Nd5 Qxb2 18.Bd6 Bxg1 19.e5 Qxa1+ '
               '20.Ke2 Na6 21.Nxg7+ Kd8 22.Qf6+ Nxf6 23.Be7#',
         key='Qf6+', nth=2),
    dict(id='evergreen', white='Adolf Anderssen', black='Jean Dufresne', place='Berlin', year=1852,
         moves='1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.b4 Bxb4 5.c3 Ba5 6.d4 exd4 7.O-O d3 8.Qb3 Qf6 9.e5 Qg6 10.Re1 Nge7 '
               '11.Ba3 b5 12.Qxb5 Rb8 13.Qa4 Bb6 14.Nbd2 Bb7 15.Ne4 Qf5 16.Bxd3 Qh5 17.Nf6+ gxf6 18.exf6 Rg8 '
               '19.Rad1 Qxf3 20.Rxe7+ Nxe7 21.Qxd7+ Kxd7 22.Bf5+ Ke8 23.Bd7+ Kf8 24.Bxe7#',
         key='Qxd7+'),
    dict(id='reti', white='Richard Reti', black='Savielly Tartakower', place='Vienna', year=1910,
         moves='1.e4 c6 2.d4 d5 3.Nc3 dxe4 4.Nxe4 Nf6 5.Qd3 e5 6.dxe5 Qa5+ 7.Bd2 Qxe5 8.O-O-O Nxe4 9.Qd8+ Kxd8 '
               '10.Bg5+ Kc7 11.Bd8#',
         key='Qd8+'),
]
