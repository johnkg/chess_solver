# Full famous games for the Learn tab (level 7), as playable lines: step through
# them with a note on the key moves, or train by playing the winner's moves.
# The moves live in famous.py (replayed by the Python engine, so a typo fails
# loudly). Notes are keyed by "17...Be6" style labels; a label that does not
# exist in the game fails the build.
from famous import GAMES, replay

GAME_LESSONS = [
    dict(game='lasker-thomas', side='white', title='Lasker vs Thomas (1912)',
         tagline='A queen sacrifice and a king hunted across the whole board.',
         why='Edward Lasker, a strong amateur master, played this attack against George Thomas in London. White built up '
             'on h7 with queen, knight and bishop, sacrificed the queen there, and then chased the king from h7 all the '
             'way to g1, where a discovered check ended it.',
         spot=['Queen, knight and bishop all aiming at h7.',
               'Each check pushes the king further from its own pieces.',
               'A quiet king move can be mate when it uncovers a rook.'],
         notes={'6.e4': 'White opens the center against Black\'s Dutch setup (...e6 and ...f5).',
                '10.Qh5': 'The queen and the knight on e5 aim at h7, with the bishop on d3 behind them.',
                '11.Qxh7+': 'The queen sacrifice: Black\'s king has to take.',
                '12.Nxf6+': 'The knight takes the bishop with check and the king is pulled further out.',
                '13.Neg4+': 'Another knight check, this time from the e5 knight.',
                '14.h4+': 'The pawn joins the hunt with check.',
                '16.Be2+': 'The bishop checks from the other side.',
                '17.Rh2+': 'The rook checks along the second rank.',
                '18.Kd2#': 'Checkmate: moving the king uncovers the rook on a1, which gives check along the first rank.'}),
    dict(game='byrne-fischer', side='black', title='The Game of the Century (1956)',
         tagline='Thirteen-year-old Bobby Fischer sacrifices his queen against Donald Byrne.',
         why='In New York in 1956 the young Fischer played one of the most celebrated games ever. After 17...Be6!! he '
             'let White take his queen, and in return his pieces gave check after check and won a great deal of '
             'material. The game ended in checkmate with every black piece taking part.',
         spot=['A sacrifice that works because every black piece is active.',
               'Repeated knight checks that win material.',
               'The white king left in the center with no defenders.'],
         notes={'11...Na4': 'The knight goes to the edge of the board but hits the queen and the knight on c3.',
                '17...Be6': 'The queen sacrifice that made the game famous: the bishop leaves the queen to be taken.',
                '18.Bxb6': 'White takes the queen.',
                '18...Bxc4+': 'Black takes a bishop with check.',
                '19...Ne2+': 'The knight starts a series of checks that wins a lot of material.',
                '25...Nxd1': 'Black collects a rook.',
                '41...Rc2#': 'Checkmate: the white king is boxed in by its own pieces.'}),
    dict(game='fischer-spassky6', side='white', title='Fischer vs Spassky, game 6 (1972)',
         tagline='The game many call the best of the World Championship match.',
         why='In Reykjavik Bobby Fischer, who nearly always opened with 1.e4, started with 1.c4 and played a Queen\'s '
             'Gambit. He built up slowly, broke open the center with e4 and e5, and used a kingside pawn advance to '
             'dominate the board. Spassky joined the audience in applauding.',
         spot=['A quiet opening, then a clear plan: e4, then e5.',
               'Trading pieces that defend the king and wrecking Black\'s pawns.',
               'Pawn advances that open lines for rooks and queen.'],
         notes={'1.c4': 'Fischer, a lifelong 1.e4 player, opens with the English move.',
                '18.Nd4': 'The knight heads for e6.',
                '19.Nxe6': 'White trades a knight for the bishop and wrecks Black\'s pawn structure.',
                '20.e4': 'White takes the center with the pawn.',
                '22.e5': 'The pawn advances again and cramps Black.',
                '26.f5': 'Opens lines against the black king.',
                '41.Qf4': 'Black resigned. White\'s pieces dominate the board.'}),
    dict(game='kasparov-topalov', side='white', title='Kasparov\'s Immortal (1999)',
         tagline='A rook sacrifice and a king driven from one end of the board to the other.',
         why='At Wijk aan Zee Garry Kasparov played 24.Rxd4!! against Veselin Topalov. Over the next ten moves the black '
             'king was drawn out of its shelter on b8 and chased all the way to d1, where 36.Bf1 left Black with no '
             'defence. Many players regard it as the best game of the modern era.',
         spot=['A rook sacrifice to open the enemy king.',
               'Checks that keep the king running.',
               'A quiet bishop move at the end that leaves no defence.'],
         notes={'1.e4': 'Black chooses the Pirc Defence.',
                '4.Be3': 'White sets up Be3, Qd2 and Bh6, aiming at the kingside.',
                '8.Bh6': 'White trades off Black\'s dark-squared bishop to weaken the king.',
                '13...O-O-O': 'Both kings are now on the queenside.',
                '24.Rxd4': 'The rook sacrifice that starts the famous combination.',
                '25.Re7+': 'The second rook joins in with check.',
                '26.Qxd4+': 'The queen takes with check and the king is dragged forward.',
                '36.Bf1': 'The quiet bishop move: Black has no defence.',
                '44.Qa7': 'Black resigned.'}),
    dict(game='deepblue-kasparov6', side='white', title='Deep Blue vs Kasparov, game 6 (1997)',
         tagline='The game in which a computer beat the world champion in a match.',
         why='In 1997 the IBM computer Deep Blue won the deciding game of its rematch against Garry Kasparov in just 19 '
             'moves. White sacrificed a knight on e6 to break open the black position, and Kasparov, playing the '
             'Caro-Kann, could not recover. It was the first time a reigning world champion lost a match to a computer.',
         spot=['A knight sacrifice that breaks up the black pawns.',
               'The king driven to d8 and kept there.',
               'Opening lines for the rooks.'],
         notes={'1...c6': 'Kasparov plays the Caro-Kann Defence.',
                '8.Nxe6': 'A known knight sacrifice that breaks open Black\'s position.',
                '10.Bg6+': 'The check drives the king to d8.',
                '17.Bf5': 'White gives a bishop to open the e-file.',
                '18.Rxe7': 'The rook takes the queen and Black is lost.',
                '19.c4': 'Kasparov resigned.'}),
]


def build():
    out = []
    for g in GAME_LESSONS:
        game = next(x for x in GAMES if x['id'] == g['game'])
        plies = list(replay(game['moves']))
        sans = [s for _, _, s in plies]
        labels = []
        number = 1
        for i, (pos, mv, s) in enumerate(plies):
            white = i % 2 == 0
            number = i // 2 + 1
            labels.append(f"{number}.{s.rstrip('+#')}" if white else f"{number}...{s.rstrip('+#')}")
        notes = [''] * len(sans)
        for key, text in g['notes'].items():
            bare = key.rstrip('+#')
            assert bare in labels, (g['game'], key)
            notes[labels.index(bare)] = text
        assert len(g['spot']) == 3
        out.append(dict(id=f"gm-{g['game']}", level=7, kind='line', title=g['title'], tagline=g['tagline'],
                        why=g['why'], spot=g['spot'], fen='rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                        side=g['side'], line=sans, notes=notes))
    return out
