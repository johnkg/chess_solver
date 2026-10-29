# Full famous games for the Learn tab (level 7), as playable lines: step through
# them with a note on the key moves, or train by playing the winner's moves.
# The moves live in famous.py (replayed by the Python engine, so a typo fails
# loudly). Notes are keyed by "17...Be6" style labels; a label that does not
# exist in the game fails the build.
from famous import GAMES, replay

GAME_LESSONS = [
    dict(game='lasker-thomas', start='11.Qxh7', side='white', title='Lasker vs Thomas (1912)',
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
    dict(game='byrne-fischer', start='17...Be6', side='black', title='The Game of the Century (1956)',
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
    dict(game='fischer-spassky6', start='26.f5', side='white', title='Fischer vs Spassky, game 6 (1972)',
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
    dict(game='kasparov-topalov', start='24.Rxd4', side='white', title='Kasparov\'s Immortal (1999)',
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
    dict(game='deepblue-kasparov6', start='8.Nxe6', side='white', title='Deep Blue vs Kasparov, game 6 (1997)',
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
    dict(game='lasker-bauer', start='15.Bxh7', side='white', title='Lasker vs Bauer (1889)',
         tagline='The double bishop sacrifice, played by a future world champion.',
         why='In Amsterdam in 1889 the young Emanuel Lasker played a famous double bishop sacrifice against Johann Bauer: '
             'the bishop took h7 with check, and after the black king took it the queen came in with check, the second '
             'bishop took g7, and the attack never stopped. The same idea decides games today.',
         spot=['Bishop on d3 and queen ready to join it against h7.',
               'A bishop on e5 that can take g7 once the king is exposed.',
               'A rook lifted to the third rank to join the attack.'],
         notes={'11.Ne5': 'The knight reaches e5, backed up by the bishop on b2.',
                '14.Nh5': 'The knight jumps to h5, hitting the knight on f6 and the pawn on g7.',
                '15.Bxh7+': 'The first bishop sacrifice: the king has to take.',
                '16.Qxh5+': 'The queen takes the knight with check.',
                '17.Bxg7': 'The second bishop sacrifice tears the king\'s shelter away.',
                '19.Rf3': 'The rook joins the attack along the third rank.',
                '20.Rh3+': 'The rook checks on the h-file.',
                '32.e7': 'The pawn will promote and Black resigned.'}),
    dict(game='steinitz-bardeleben', start='22.Rxe7', side='white', title='Steinitz vs von Bardeleben (1895)',
         tagline='A rook sacrifice on e7 that rips the king out of the position, at Hastings.',
         why='Wilhelm Steinitz, the first official world champion, won this game against Curt von Bardeleben at Hastings. '
             'White played d5 to open the center, put a knight on e6, and sacrificed a rook on e7. Legend says von '
             'Bardeleben left the room rather than resign.',
         spot=['A pawn break that opens the center.',
               'A knight on e6 that attacks c7 and g7.',
               'Rooks swinging into the seventh rank with check.'],
         notes={'17.d5': 'The pawn break opens the center.',
                '19.Ne6': 'The knight lands on e6, where it attacks c7 and g7.',
                '22.Rxe7+': 'A rook sacrifice: the king is dragged into the open.',
                '25.Rxh7+': 'The rook takes with check. The game continued only a few more moves; legend says von Bardeleben walked out rather than resign.'}),
    dict(game='karpov-kasparov16', start='33...Ne4', side='black', title='Karpov vs Kasparov, game 16 (1985)',
         tagline='A knight on d3 that Karpov could never remove.',
         why='In the 1985 world championship match in Moscow Garry Kasparov, Black, planted a knight on d3 on move 16 and '
             'kept it there for almost twenty moves. White\'s pieces were tied up around it, and in the end Kasparov won '
             'the queen. It is one of the most admired games of the match, which he won to become world champion.',
         spot=['A knight on d3 supported by a bishop and a rook.',
               'The white pieces forced to babysit one square.',
               'A knight sacrifice at the end that wins the queen.'],
         notes={'1.e4': 'Kasparov (Black) answers with the Sicilian Defence.',
                '6.c4': 'White takes space in the center.',
                '16...Nd3': 'The knight lands on d3: no white pawn can ever attack it.',
                '21...g5': 'Black gains space on the kingside.',
                '34...Nf2+': 'The knight forks the king and the queen.',
                '35...Bxd3': 'The bishop takes the white queen.',
                '40...Re1+': 'White resigned.'}),
    dict(game='shilling', side='black', title='The Blackburne Shilling Gambit',
         tagline='A trap that mates a greedy opponent in seven moves.',
         why='After 3...Nd4 White is tempted to take e5 and then f7. It looks like free pawns, but the black queen and '
             'knight turn it into a mating attack. The name comes from the legend that the English master Joseph '
             'Blackburne won shillings from opponents who fell for it.',
         spot=['A knight on d4 that looks careless.',
               'The queen on g5 hitting e5 and g2 at once.',
               'A king stuck on e1 with its own pieces around it.'],
         notes={'3...Nd4': 'The bait: the knight invites White to take on e5.',
                '4.Nxe5': 'White takes the pawn.',
                '4...Qg5': 'The queen attacks the knight on e5 and the pawn on g2.',
                '5.Nxf7': 'Greedy: White attacks the queen and the rook.',
                '5...Qxg2': 'The queen takes g2 and attacks the rook on h1.',
                '6.Rf1': 'White moves the rook out of attack.',
                '6...Qxe4+': 'The queen takes with check.',
                '7.Be2': 'White blocks the check.',
                '7...Nf3#': 'Checkmate: the knight gives check and the white king has no escape.'}),
    dict(game='scholar', side='white', title='Scholar\'s mate',
         tagline='The four-move mate every beginner should know, and know how to stop.',
         why='White brings the queen and bishop to f7 and mates on move four. Black can stop it easily by defending f7 '
             'with a move like ...Qe7 or ...g6. If you ever play it, expect a good opponent to stop it, and develop your '
             'pieces calmly.',
         spot=['Queen and bishop both aiming at f7.',
               'f7 is defended only by the king.',
               'A black move that attacks the queen is not always a defence.'],
         notes={'2.Bc4': 'The bishop aims at f7.',
                '3.Qh5': 'The queen joins the bishop in the attack on f7.',
                '3...Nf6': 'Attacks the queen but does not defend f7.',
                '4.Qxf7#': 'Checkmate.'}),
    dict(game='caro-miniature', side='white', title='The Caro-Kann miniature',
         tagline='A six-move mate by a knight against a king with no air.',
         why='In the Caro-Kann Defence Black\'s pieces are crowded around the king. If Black plays 5...Ngf6?? the knight '
             'on e4 jumps to d6 with checkmate, because the king has no square and its own pieces block every escape.',
         spot=['A knight on e4 eyeing d6.',
               'A king with its own queen, bishop and pawn around it.',
               'A natural developing move that walks into mate.'],
         notes={'3.Nc3': 'White defends the e-pawn and develops.',
                '5.Qe2': 'White sets a trap: Black must not play ...Ngf6.',
                '5...Ngf6': 'The blunder: it leaves d6 undefended and boxes the king in.',
                '6.Nd6#': 'Checkmate: the knight gives check and Black\'s own pieces block every escape.'}),
    dict(game='elephant', side='black', title='The Elephant Trap',
         tagline='If White grabs a pawn on d5, Black wins a piece with a pin on the d-file.',
         why='In the Queen\'s Gambit Declined White\'s knight can take the pawn on d5, but then Black takes the knight and '
             'the queen on d8 looks lost. After 7.Bxd8 Bb4+ the bishop wins the queen back, because in the '
             'main line the white queen has to block and is taken, and Black comes out a knight for a pawn ahead.',
         spot=['A knight on d5 that looks free but is pinned in effect.',
               'A bishop check that forces the queen to block.',
               'Counting the whole sequence, not just the first capture.'],
         notes={'4.Bg5': 'The bishop pins the knight on f6 against the queen.',
                '6.Nxd5': 'White takes the pawn. This is the mistake.',
                '6...Nxd5': 'Black takes the knight, and the bishop on g5 now takes the queen.',
                '7.Bxd8': 'White takes the queen.',
                '7...Bb4+': 'The check wins the queen back.',
                '8.Qd2': 'White blocks with the queen.',
                '9...Kxd8': 'Black has won a knight for a pawn.'}),
    dict(game='rotlewi-rubinstein', start='22...Rxc3', side='black', title='Rotlewi vs Rubinstein (1907)',
         tagline="Rubinstein's Immortal: two rook sacrifices in a row.",
         why='Akiba Rubinstein played this game in Lodz against Georg Rotlewi. White pushed forward on the kingside, '
             'and Black answered with two rook sacrifices in a row: first on c3, then on d2. After the white queen '
             'took, the bishop gave check, and the rook went to h3 with an unstoppable mating attack. Many '
             'players rank it among the most beautiful games ever played.',
         spot=["Black's pieces all aim at the white king after e5 and f4.",
               'A rook sacrifice that opens the c-file and pulls the white pawns apart.',
               'The second rook sacrifice, on d2, deflects the queen from the defence of g2.'],
         notes={'8.b4': 'White grabs space on the queenside, but it loosens the squares around the c3 knight.',
                '15...Ne5': 'The knight trades off a defender and heads for the kingside.',
                '19.e5': 'White pushes the pawn and gives up the long diagonal, which Black will use.',
                '19...Bb6+': 'The bishop checks along the diagonal toward the king.',
                '20...Ng4': 'The knight joins in: it eyes h2 and f2.',
                '21...Qh4': 'The queen swings to the kingside and threatens mate.',
                '22...Rxc3': "The first rook sacrifice: it pulls a defender away and opens the c-file.",
                '23.gxh4': 'White takes the queen.',
                '23...Rd2': 'The second rook sacrifice. If the queen takes, the bishop checks and White is lost.',
                '24.Qxd2': 'The queen takes the rook.',
                '24...Bxe4+': 'The bishop takes with check and the white queen has to block on g2.',
                '25...Rh3': 'The last move: Black threatens mate and White resigned.'}),
    dict(game='budapest-miniature', side='black', title='The Budapest Gambit trap',
         tagline='A knight check on d3 is checkmate on move 8.',
         why='In the Budapest Gambit Black gives up a pawn for quick development. If White takes the bishop on '
             'move 8, a knight check on d3 is checkmate: the queen on e7 covers e2 and the white knight on d2 '
             'blocks its own king.',
         spot=['The queen on e7 aims down the e-file, covering e2.',
               "White's own knight on d2 blocks the king's escape.",
               'A knight check on d3 that cannot be captured.'],
         notes={'3...Ng4': 'The knight hits the pawn on e5 and the Budapest Gambit is on.',
                '5...Bb4+': 'The bishop checks and a white piece has to block.',
                '6...Qe7': 'The queen adds to the pressure on the e-file.',
                '7...Ngxe5': 'Black wins the pawn back; the knight now has d3 in sight.',
                '8.axb4': 'White takes the bishop. This blunder loses on the spot.',
                '8...Nd3': 'Checkmate: the king cannot reach e2, d2 or d1.'}),
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
        extra = {}
        if 'start' in g:
            # Where "start at the combination" begins: the ply of this move.
            assert g['start'].rstrip('+#') in labels, (g['game'], g['start'])
            extra['start'] = labels.index(g['start'].rstrip('+#'))
        out.append(dict(**extra, id=f"gm-{g['game']}", level=7, kind='line', title=g['title'], tagline=g['tagline'],
                        why=g['why'], spot=g['spot'], fen='rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                        side=g['side'], line=sans, notes=notes))
    return out
