# Opening lines for the Learn tab (level 8). Only the moves and one note per
# move are typed in: positions are replayed with the Python engine, so a typo
# fails loudly, and the SAN is rewritten in canonical form (check marks, file
# letters for ambiguous knights).
#
# `moves` and `notes` have the same length; an empty note means "nothing to add".
from famous import replay

START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'

OPENINGS = [
    dict(id='op-italian', side='white', title='Italian Game',
         tagline='Develop fast, aim at f7, and build a big center with c3 and d4.',
         why='The Italian is one of the oldest openings and a perfect first one to learn. White develops the king\'s knight '
             'and bishop to natural squares, aims at the weak f7 pawn, then plays c3 and d4 to take the center.',
         spot=['Knight to f3, bishop to c4, then castle.', 'c3 prepares d4: the pawn center is the point.',
               'Watch f7: it is only defended by the king.'],
         moves='e4 e5 Nf3 Nc6 Bc4 Bc5 c3 Nf6 d4 exd4 cxd4 Bb4+ Bd2 Bxd2+ Nbxd2 d5 exd5 Nxd5 Qb3 Nce7 O-O',
         notes=['Claims the center and opens lines for the queen and bishop.', 'Black claims the center too.',
                'Develops a knight and attacks the e5 pawn.', 'Defends e5 and develops a piece.',
                'The bishop aims at f7, Black\'s weakest square.', 'Black copies: the Giuoco Piano, "the quiet game".',
                'Prepares d4 to build a big pawn center.', 'Develops and attacks the pawn on e4.',
                'Strikes at the center: the e5 pawn is now under fire.', 'Black takes the pawn.',
                'White recaptures and has a strong pawn center.', 'A check that gains time.',
                'Meets the check by blocking with a developing move.', 'Black trades bishops.',
                'Recaptures with the b-knight, keeping the other knight on f3.', 'Black hits back at the center.',
                'White takes first.', 'Black recaptures.', 'Attacks the knight on d5 and adds pressure on f7.',
                'Defends the knight on d5.', 'The king is safe and the rook joins the game.']),
    dict(id='op-ruy', side='white', title='Ruy Lopez',
         tagline='Pressure the knight that defends e5 and keep a lasting initiative.',
         why='The Ruy Lopez is the main opening of top-level chess for centuries. The bishop on b5 does not threaten '
             'to win a pawn at once; it pressures the knight that defends e5 and keeps the tension for the whole game.',
         spot=['Bishop to b5, then castle quickly.', 'Re1 and c3, then d4 to open the center.',
               'Keep the bishop: retreat with Ba4 and Bb3 rather than trading it early.'],
         moves='e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5 Bb3 d6 c3 O-O h3',
         notes=['Claims the center.', 'Black does the same.', 'Attacks e5 and develops.', 'Defends e5.',
                'Pressures the knight that defends e5.', 'Asks the bishop what it wants to do.',
                'Keeps the pin on the knight and keeps the bishop.', 'Develops and attacks e4.',
                'Castling first: the pawn on e4 is defended tactically.', 'Black develops and prepares to castle.',
                'Defends e4 and prepares to take on e5 later.', 'Gains space and kicks the bishop.',
                'The bishop retreats to a good diagonal aimed at f7.', 'Black supports the e5 pawn.',
                'Prepares d4 and makes room on c2 for the bishop.', 'Black castles.',
                'Stops ...Bg4, which would pin the f3 knight.']),
    dict(id='op-qgd', side='white', title='Queen\'s Gambit Declined',
         tagline='Offer a pawn to win the center, and keep the long-term pressure.',
         why='The Queen\'s Gambit is not a real gambit: if Black takes the pawn, White gets it back and keeps the better '
             'center. Black can decline with ...e6 and keep a solid position, which is the classical way to play it.',
         spot=['c4 attacks the d5 pawn from the side.', 'Develop knights before bishops and castle.',
               'If Black takes on c4, recapture and use the open lines.'],
         moves='d4 d5 c4 e6 Nc3 Nf6 Bg5 Be7 e3 O-O Nf3 Nbd7 Rc1 c6 Bd3 dxc4 Bxc4 Nd5 Bxe7 Qxe7 O-O Nxc3 Rxc3 e5',
         notes=['Claims the center and opens the queen\'s bishop.', 'Black claims the center too.',
                'Attacks the d5 pawn: if it is taken, White gets it back.', 'Declines the gambit and keeps d5 solid.',
                'Develops and adds pressure on d5.', 'Develops and defends d5.',
                'Pins the knight to the queen and adds pressure on d5.', 'Unpins and prepares to castle.',
                'Supports the center and opens the bishop on f1.', 'Black castles.',
                'Develops the second knight.', 'Develops and guards f6.',
                'Puts the rook on the c-file, ready for the center to open.', 'Prepares ...dxc4 and ...e5.',
                'Develops and invites ...dxc4, after which Bxc4 gains time.', 'Black takes the pawn at last.',
                'The bishop recaptures and now eyes the kingside.', 'Frees the position by offering trades.',
                'Trades off the bishop on e7.', 'Recaptures.', 'The king is safe.', 'Trades another pair.',
                'Recaptures with the rook.', 'Black breaks in the center and equalizes.']),
    dict(id='op-london', side='white', title='London System',
         tagline='A solid setup you can play against almost anything.',
         why='The London is easy to learn: the same few moves every game. The bishop goes to f4 before the e-pawn closes '
             'it in, then pawns on d4, e3 and c3 form a sturdy structure and the knights come out to d2 and f3.',
         spot=['Bishop to f4 BEFORE e3.', 'Pawns on d4, e3 and c3 make a solid triangle.',
               'The bishop on f4 and the knights on d2 and f3 are the usual setup.'],
         moves='d4 d5 Bf4 Nf6 e3 c5 c3 Nc6 Nd2 e6 Ngf3 Bd6 Bg3 O-O Bd3',
         notes=['Claims the center.', 'Black does the same.', 'Develops the bishop outside the pawn chain.',
                'Develops a knight.', 'Solid center, and the bishop on f1 is free.', 'Black attacks d4.',
                'Supports d4.', 'Adds pressure on d4.',
                'Supports e4 later and prepares Ngf3.', 'Black opens the bishop on f8.',
                'Develops and defends d4.', 'Black eyes the bishop on f4.',
                'Keeps the bishop; a trade on g3 would open the h-file for White.', 'Black castles.',
                'The last minor piece comes out and eyes h7.']),
    dict(id='op-najdorf', side='black', title='Sicilian Najdorf',
         tagline='Fight for the center with a flank pawn and play for a win as Black.',
         why='The Sicilian answers 1.e4 with 1...c5 and fights for d4 from the side. The Najdorf (...a6) is the most '
             'popular line at all levels: it controls b5 and keeps Black\'s options open.',
         spot=['...c5 and ...d6, then take on d4.', '...a6 stops a knight or bishop landing on b5.',
               'Black gets an unbalanced game with chances to win.'],
         moves='e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be3 e5 Nb3 Be6 f3 Be7 Qd2 O-O O-O-O Nbd7',
         notes=['White claims the center.', 'Fights for d4 from the side instead of copying.',
                'Develops and prepares d4.', 'Supports a later ...e5 and opens the bishop.',
                'Opens the center.', 'Black trades the c-pawn for White\'s d-pawn.', 'The knight recaptures.',
                'Develops and attacks the pawn on e4.', 'Defends e4.', 'The Najdorf move: controls b5.',
                'The English Attack: a solid setup with f3 and Qd2.', 'Kicks the knight and claims the center.',
                'The knight retreats.', 'Develops and eyes the c4 square.', 'Supports e4 and prepares Qd2.',
                'Develops and prepares to castle.', 'Prepares long castling.', 'Black castles.',
                'White castles long and the sides will attack each other.', 'Develops the last knight.']),
    dict(id='op-french', side='black', title='French Defence',
         tagline='Build a solid chain with ...e6 and ...d5, then attack it with ...c5.',
         why='The French gives Black a rock-solid pawn chain. The light-squared bishop is the problem piece, but '
             'Black strikes at the white center with ...c5 and ...f6 to open the game when the time is right.',
         spot=['...e6 and ...d5 first, then ...c5.', 'Attack the base of White\'s chain at d4.',
               'The bishop on c8 is the piece to worry about.'],
         moves='e4 e6 d4 d5 Nc3 Nf6 Bg5 Be7 e5 Nfd7 Bxe7 Qxe7 f4 O-O Nf3 c5',
         notes=['White claims the center.', 'Prepares ...d5.', 'White takes space.', 'Black challenges the e4 pawn.',
                'Defends e4.', 'Attacks the pawn on e4 again.', 'Pins the knight to the queen.', 'Unpins and prepares to castle.',
                'White gains space and attacks the knight.', 'The knight retreats and prepares ...c5.',
                'Trades off the dangerous bishop.', 'Recaptures.', 'Supports the e5 pawn.', 'Black castles.',
                'Develops the knight.', 'The thematic strike at the white chain.']),
    dict(id='op-caro', side='black', title='Caro-Kann',
         tagline='A solid defence: the bishop leaves the pawn chain before ...e6.',
         why='The Caro-Kann prepares ...d5 with ...c6, so that after the exchange of pawns Black can play ...Bf5 and '
             'develop the bishop that the French defence buries behind its pawns.',
         spot=['...c6 then ...d5.', 'Develop the c8 bishop outside the chain (...Bf5) before ...e6.',
               'A solid structure and a good endgame.'],
         moves='e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5 Ng3 Bg6 h4 h6 Nf3 Nd7 h5 Bh7 Bd3 Bxd3 Qxd3 e6',
         notes=['White claims the center.', 'Prepares ...d5 without blocking the bishop.', 'White takes the center.',
                'Black challenges the center.', 'Defends e4.', 'Black takes the pawn.', 'White recaptures.',
                'The bishop comes out BEFORE ...e6 closes it in.', 'Attacks the bishop.', 'The bishop is safe on g6.',
                'White threatens h5 to chase the bishop.', 'Black makes room for the bishop on h7.', 'Develops.',
                'Develops and prepares ...Ngf6.', 'Attacks the bishop.', 'The bishop retreats.',
                'White offers the trade.', 'Black trades the bishops.', 'Recaptures.', 'Black finishes the setup.']),
    dict(id='op-kid', side='black', title='King\'s Indian Defence',
         tagline='Let White take the center, then strike at it and attack the king.',
         why='In the King\'s Indian Black allows White a big pawn center on purpose. The bishop on g7 and a later ...e5 or ...c5 '
             'strike at it, and the fianchettoed king\'s bishop is a monster when the center opens.',
         spot=['Knight to f6, pawn to g6, bishop to g7, castle.', 'Strike at the center with ...e5 or ...c5.',
               'Later: a kingside pawn storm with ...f5 and ...g5.'],
         moves='d4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2 e5 O-O Nc6 d5 Ne7',
         notes=['White claims the center.', 'Develops and controls e4.', 'Takes more space.',
                'Prepares to put the bishop on g7.', 'Develops.', 'The bishop eyes the long diagonal.',
                'White builds a big center.', 'Prepares ...e5 and opens the c8 bishop.', 'Develops and protects e4.',
                'Black castles: the king is safe.', 'Develops.', 'The classical strike at the center.',
                'White castles.', 'Adds pressure on d4.', 'White gains space and closes the position.',
                'Black retreats the knight to prepare ...f5, the kingside attack.']),
]


# Alternative lines: the other side's different replies (name, moves from move 1). The
# trainer merges them with the main line into a tree.
BRANCHES = {'op-italian': [('Two Knights Defence', 'e4 e5 Nf3 Nc6 Bc4 Nf6 Ng5 d5 exd5 Na5 Bb5+ c6 dxc6 bxc6 Be2 h6 Nf3 e4 Ne5 Bd6 d4'),
     ('Hungarian Defence', 'e4 e5 Nf3 Nc6 Bc4 Be7 d4 exd4 Nxd4 Nf6 Nc3 O-O')], 'op-ruy': [('Berlin Defence', 'e4 e5 Nf3 Nc6 Bb5 Nf6 O-O Nxe4 d4 Nd6 Bxc6 dxc6 dxe5 Nf5 Qxd8+ Kxd8'),
     ('Steinitz Defence', 'e4 e5 Nf3 Nc6 Bb5 d6 d4 Bd7 Nc3 Nf6 O-O Be7 Re1 exd4 Nxd4 O-O'),
     ('Open Defence', 'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Nxe4 d4 b5 Bb3 d5 dxe5 Be6 c3 Be7')], 'op-qgd': [("Queen's Gambit Accepted", 'd4 d5 c4 dxc4 Nf3 Nf6 e3 e6 Bxc4 c5 O-O a6'),
     ('Slav Defence', 'd4 d5 c4 c6 Nf3 Nf6 Nc3 dxc4 a4 Bf5 e3 e6 Bxc4 Bb4 O-O Nbd7'),
     ('Tarrasch Defence', 'd4 d5 c4 e6 Nc3 c5 cxd5 exd5 Nf3 Nc6 g3 Nf6 Bg2 Be7 O-O O-O'),
     ('Albin Countergambit', 'd4 d5 c4 e5 dxe5 d4 Nf3 Nc6 g3 Be6 Nbd2 Qd7')], 'op-london': [('Black plays ...e6', 'd4 d5 Bf4 Nf6 e3 e6 Nf3 Bd6 Bg3 O-O Nbd2 b6 Bd3 Bb7'),
     ("King's Indian setup", 'd4 Nf6 Bf4 g6 e3 Bg7 Nf3 O-O Be2 d6 h3 Nbd7 O-O'),
     ('Black plays ...c5 and ...Qb6', 'd4 d5 Bf4 c5 e3 Nc6 c3 Qb6 Qb3 c4 Qxb6 axb6 Nd2 Bf5')], 'op-najdorf': [('6.Bg5', 'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Bg5 e6 f4 Be7 Qf3 Qc7 O-O-O Nbd7'),
     ('6.Be2', 'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be2 e5 Nb3 Be7 O-O O-O Be3 Be6'),
     ('6.Bc4', 'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Bc4 e6 Bb3 b5 O-O Be7 Qf3 Qc7')], 'op-french': [('Advance Variation', 'e4 e6 d4 d5 e5 c5 c3 Nc6 Nf3 Qb6 a3 c4 Nbd2 Bd7'),
     ('Exchange Variation', 'e4 e6 d4 d5 exd5 exd5 Nf3 Nf6 Bd3 Bd6 O-O O-O'),
     ('Tarrasch Variation', 'e4 e6 d4 d5 Nd2 c5 exd5 exd5 Ngf3 Nc6 Bb5 Bd6 dxc5 Bxc5 O-O Ne7')], 'op-caro': [('Advance Variation', 'e4 c6 d4 d5 e5 Bf5 Nf3 e6 Be2 c5 Be3 cxd4 Nxd4 Ne7'),
     ('Exchange Variation', 'e4 c6 d4 d5 exd5 cxd5 Bd3 Nc6 c3 Nf6 Bf4 Bg4 Qb3 Qd7'),
     ('Panov Attack', 'e4 c6 d4 d5 exd5 cxd5 c4 Nf6 Nc3 e6 Nf3 Be7 cxd5 Nxd5 Bd3 Nc6 O-O O-O')], 'op-kid': [('Sämisch Variation', 'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 f3 O-O Be3 e5 d5 Nh5 Qd2 f5'),
     ('Fianchetto Variation', 'd4 Nf6 c4 g6 g3 Bg7 Bg2 O-O Nc3 d6 Nf3 Nbd7 O-O e5 e4 c6'),
     ('Four Pawns Attack', 'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 f4 O-O Nf3 c5 d5 e6 Be2 exd5 cxd5 Bg4')]}


def branches_of(oid, main):
    """The extra lines of an opening as canonical SAN, checked to branch off the main line."""
    names, lines = [], []
    for name, moves in BRANCHES.get(oid, []):
        sans = [s for _, _, s in replay(moves)]
        assert sans != main and sans[:len(main)] != main and main[:len(sans)] != sans, (oid, name)
        assert all(sans[:len(o)] != o and o[:len(sans)] != sans for o in lines), (oid, name)
        names.append(name)
        lines.append(sans)
    return dict(branch_names=names, branches=[' '.join(l) for l in lines]) if lines else {}


def build():
    """Lesson dicts (level 8, kind 'line') with canonical SAN."""
    out = []
    for o in OPENINGS:
        sans = [s for _, _, s in replay(o['moves'])]
        assert len(sans) == len(o['notes']), (o['id'], len(sans), len(o['notes']))
        assert len(o['spot']) == 3, o['id']
        out.append(dict(id=o['id'], level=8, kind='line', title=o['title'], tagline=o['tagline'],
                        why=o['why'], spot=o['spot'], fen=START, side=o['side'],
                        line=sans, notes=o['notes'], **branches_of(o['id'], sans)))
    return out


if __name__ == '__main__':
    for l in build():
        print(l['id'], len(l['line']), ' '.join(l['line']))
