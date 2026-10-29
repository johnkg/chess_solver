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
    dict(id='fool', intro="Fool's mate, the shortest possible game. ",
         moves='1.f3 e5 2.g4 Qh4#', key='Qh4#'),
    dict(id='lasker-thomas', white='Edward Lasker', black='George Thomas', place='London', year=1912,
         moves='1.d4 e6 2.Nf3 f5 3.Nc3 Nf6 4.Bg5 Be7 5.Bxf6 Bxf6 6.e4 fxe4 7.Nxe4 b6 8.Ne5 O-O 9.Bd3 Bb7 10.Qh5 Qe7 '
               '11.Qxh7+ Kxh7 12.Nxf6+ Kh6 13.Neg4+ Kg5 14.h4+ Kf4 15.g3+ Kf3 16.Be2+ Kg2 17.Rh2+ Kg1 18.Kd2#',
         key='Kd2#'),
    dict(id='byrne-fischer', white='Donald Byrne', black='Bobby Fischer', place='New York', year=1956,
         moves='1.Nf3 Nf6 2.c4 g6 3.Nc3 Bg7 4.d4 O-O 5.Bf4 d5 6.Qb3 dxc4 7.Qxc4 c6 8.e4 Nbd7 9.Rd1 Nb6 10.Qc5 Bg4 '
               '11.Bg5 Na4 12.Qa3 Nxc3 13.bxc3 Nxe4 14.Bxe7 Qb6 15.Bc4 Nxc3 16.Bc5 Rfe8+ 17.Kf1 Be6 18.Bxb6 Bxc4+ '
               '19.Kg1 Ne2+ 20.Kf1 Nxd4+ 21.Kg1 Ne2+ 22.Kf1 Nc3+ 23.Kg1 axb6 24.Qb4 Ra4 25.Qxb6 Nxd1 26.h3 Rxa2 '
               '27.Kh2 Nxf2 28.Re1 Rxe1 29.Qd8+ Bf8 30.Nxe1 Bd5 31.Nf3 Ne4 32.Qb8 b5 33.h4 h5 34.Ne5 Kg7 35.Kg1 Bc5+ '
               '36.Kf1 Ng3+ 37.Ke1 Bb4+ 38.Kd1 Bb3+ 39.Kc1 Ne2+ 40.Kb1 Nc3+ 41.Kc1 Rc2#',
         key='Rc2#'),
    dict(id='fischer-spassky6', white='Bobby Fischer', black='Boris Spassky', place='Reykjavik', year=1972,
         moves='1.c4 e6 2.Nf3 d5 3.d4 Nf6 4.Nc3 Be7 5.Bg5 O-O 6.e3 h6 7.Bh4 b6 8.cxd5 Nxd5 9.Bxe7 Qxe7 10.Nxd5 exd5 '
               '11.Rc1 Be6 12.Qa4 c5 13.Qa3 Rc8 14.Bb5 a6 15.dxc5 bxc5 16.O-O Ra7 17.Be2 Nd7 18.Nd4 Qf8 19.Nxe6 fxe6 '
               '20.e4 d4 21.f4 Qe7 22.e5 Rb8 23.Bc4 Kh8 24.Qh3 Nf8 25.b3 a5 26.f5 exf5 27.Rxf5 Nh7 28.Rcf1 Qd8 '
               '29.Qg3 Re7 30.h4 Rbb7 31.e6 Rbc7 32.Qe5 Qe8 33.a4 Qd8 34.R1f2 Qe8 35.R2f3 Qd8 36.Bd3 Qe8 37.Qe4 Nf6 '
               '38.Rxf6 gxf6 39.Rxf6 Kg8 40.Bc4 Kh8 41.Qf4',
         key='Qf4'),
    dict(id='kasparov-topalov', white='Garry Kasparov', black='Veselin Topalov', place='Wijk aan Zee', year=1999,
         moves='1.e4 d6 2.d4 Nf6 3.Nc3 g6 4.Be3 Bg7 5.Qd2 c6 6.f3 b5 7.Nge2 Nbd7 8.Bh6 Bxh6 9.Qxh6 Bb7 10.a3 e5 '
               '11.O-O-O Qe7 12.Kb1 a6 13.Nc1 O-O-O 14.Nb3 exd4 15.Rxd4 c5 16.Rd1 Nb6 17.g3 Kb8 18.Na5 Ba8 19.Bh3 d5 '
               '20.Qf4+ Ka7 21.Rhe1 d4 22.Nd5 Nbxd5 23.exd5 Qd6 24.Rxd4 cxd4 25.Re7+ Kb6 26.Qxd4+ Kxa5 27.b4+ Ka4 '
               '28.Qc3 Qxd5 29.Ra7 Bb7 30.Rxb7 Qc4 31.Qxf6 Kxa3 32.Qxa6+ Kxb4 33.c3+ Kxc3 34.Qa1+ Kd2 35.Qb2+ Kd1 '
               '36.Bf1 Rd2 37.Rd7 Rxd7 38.Bxc4 bxc4 39.Qxh8 Rd3 40.Qa8 c3 41.Qa4+ Ke1 42.f4 f5 43.Kc1 Rd2 44.Qa7',
         key='Qa7'),
    dict(id='deepblue-kasparov6', white='Deep Blue', black='Garry Kasparov', place='New York', year=1997,
         moves='1.e4 c6 2.d4 d5 3.Nc3 dxe4 4.Nxe4 Nd7 5.Ng5 Ngf6 6.Bd3 e6 7.N1f3 h6 8.Nxe6 Qe7 9.O-O fxe6 10.Bg6+ Kd8 '
               '11.Bf4 b5 12.a4 Bb7 13.Re1 Nd5 14.Bg3 Kc8 15.axb5 cxb5 16.Qd3 Bc6 17.Bf5 exf5 18.Rxe7 Bxe7 19.c4',
         key='c4'),
    dict(id='lasker-bauer', white='Emanuel Lasker', black='Johann Bauer', place='Amsterdam', year=1889,
         moves='1.f4 d5 2.e3 Nf6 3.b3 e6 4.Bb2 Be7 5.Bd3 b6 6.Nc3 Bb7 7.Nf3 Nbd7 8.O-O O-O 9.Ne2 c5 10.Ng3 Qc7 '
               '11.Ne5 Nxe5 12.Bxe5 Qc6 13.Qe2 a6 14.Nh5 Nxh5 15.Bxh7+ Kxh7 16.Qxh5+ Kg8 17.Bxg7 Kxg7 18.Qg4+ Kh7 '
               '19.Rf3 e5 20.Rh3+ Qh6 21.Rxh6+ Kxh6 22.Qd7 Bf6 23.Qxb7 Kg7 24.Rf1 Rab8 25.Qd7 Rfd8 26.Qg4+ Kf8 '
               '27.fxe5 Bg7 28.e6 Rb7 29.Qg6 f6 30.Rxf6+ Bxf6 31.Qxf6+ Kg8 32.e7',
         key='Bxh7+'),
    dict(id='steinitz-bardeleben', white='Wilhelm Steinitz', black='Curt von Bardeleben', place='Hastings', year=1895,
         moves='1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.c3 Nf6 5.d4 exd4 6.cxd4 Bb4+ 7.Nc3 d5 8.exd5 Nxd5 9.O-O Be6 10.Bg5 Be7 '
               '11.Bxd5 Bxd5 12.Nxd5 Qxd5 13.Bxe7 Nxe7 14.Re1 f6 15.Qe2 Qd7 16.Rac1 c6 17.d5 cxd5 18.Nd4 Kf7 '
               '19.Ne6 Rhc8 20.Qg4 g6 21.Ng5+ Ke8 22.Rxe7+ Kf8 23.Rf7+ Kg8 24.Rg7+ Kh8 25.Rxh7+',
         key='Rxh7+'),
    dict(id='karpov-kasparov16', white='Anatoly Karpov', black='Garry Kasparov', place='Moscow', year=1985,
         moves='1.e4 c5 2.Nf3 e6 3.d4 cxd4 4.Nxd4 Nc6 5.Nb5 d6 6.c4 Nf6 7.N1c3 a6 8.Na3 d5 9.cxd5 exd5 10.exd5 Nb4 '
               '11.Be2 Bc5 12.O-O O-O 13.Bf3 Bf5 14.Bg5 Re8 15.Qd2 b5 16.Rad1 Nd3 17.Nab1 h6 18.Bh4 b4 19.Na4 Bd6 '
               '20.Bg3 Rc8 21.b3 g5 22.Bxd6 Qxd6 23.g3 Nd7 24.Bg2 Qf6 25.a3 a5 26.axb4 axb4 27.Qa2 Bg6 28.d6 g4 '
               '29.Qd2 Kg7 30.f3 Qxd6 31.fxg4 Qd4+ 32.Kh1 Nf6 33.Rf4 Ne4 34.Qxd3 Nf2+ 35.Rxf2 Bxd3 36.Rfd2 Qe3 '
               '37.Rxd3 Rc1 38.Nb2 Qf2 39.Nd2 Rxd1+ 40.Nxd1 Re1+',
         key='Nf2+'),
    dict(id='shilling', intro='The Blackburne Shilling Gambit. ', white='Beginner', black='Blackburne', place='London', year=1880,
         moves='1.e4 e5 2.Nf3 Nc6 3.Bc4 Nd4 4.Nxe5 Qg5 5.Nxf7 Qxg2 6.Rf1 Qxe4+ 7.Be2 Nf3#', key='Nf3#'),
    dict(id='scholar', intro="Scholar's mate. ", white='White', black='Black', place='anywhere', year=1600,
         moves='1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#', key='Qxf7#'),
    dict(id='caro-miniature', intro='The Caro-Kann miniature. ', white='White', black='Black', place='anywhere', year=1900,
         moves='1.e4 c6 2.d4 d5 3.Nc3 dxe4 4.Nxe4 Nd7 5.Qe2 Ngf6 6.Nd6#', key='Nd6#'),
    dict(id='elephant', intro='The Elephant Trap. ', white='White', black='Black', place='anywhere', year=1900,
         moves='1.d4 d5 2.c4 e6 3.Nc3 Nf6 4.Bg5 Nbd7 5.cxd5 exd5 6.Nxd5 Nxd5 7.Bxd8 Bb4+ 8.Qd2 Bxd2+ 9.Kxd2 Kxd8',
         key='Bb4+'),
    dict(id='rotlewi-rubinstein', white='Georg Rotlewi', black='Akiba Rubinstein', place='Lodz', year=1907,
         moves='1.d4 d5 2.Nf3 e6 3.e3 c5 4.c4 Nc6 5.Nc3 Nf6 6.dxc5 Bxc5 7.a3 a6 8.b4 Bd6 9.Bb2 O-O 10.Qd2 Qe7 '
               '11.Bd3 dxc4 12.Bxc4 b5 13.Bd3 Rd8 14.Qe2 Bb7 15.O-O Ne5 16.Nxe5 Bxe5 17.f4 Bc7 18.e4 Rac8 19.e5 Bb6+ '
               '20.Kh1 Ng4 21.Be4 Qh4 22.g3 Rxc3 23.gxh4 Rd2 24.Qxd2 Bxe4+ 25.Qg2 Rh3',
         key='Rxc3'),
    dict(id='budapest-miniature', intro='The Budapest Gambit trap. ', white='White', black='Black', place='anywhere', year=1900,
         moves='1.d4 Nf6 2.c4 e5 3.dxe5 Ng4 4.Bf4 Nc6 5.Nf3 Bb4+ 6.Nbd2 Qe7 7.a3 Ngxe5 8.axb4 Nd3#', key='Nd3#'),
]


if __name__ == '__main__':
    # famous_games.json: the games as SAN lists, for tool/famous_scan.dart.
    import json
    import os
    out = [dict(id=g['id'], sans=[san_ for _, _, san_ in replay(g['moves'])]) for g in GAMES]
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'famous_games.json')
    with open(path, 'w') as f:
        json.dump(out, f)
    print('wrote', len(out), 'games to', path)
