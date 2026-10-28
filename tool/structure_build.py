# Builds the Level 6 (middlegame structure) lessons and the "find" drills from
# structure_data.py. The target squares are only a record: test/structure_data_test.dart
# re-computes them with lib/engine/structure.dart and fails on any difference.
from structure_data import STRUCTURE

NAMES = {
    'passed': ('passed pawn', 'passed pawns'),
    'isolated': ('isolated pawn', 'isolated pawns'),
    'doubled': ('doubled pawn', 'doubled pawns'),
    'backward': ('backward pawn', 'backward pawns'),
    'openFile': ('open file', 'open files'),
    'outpost': ('outpost', 'outposts'),
}

LESSON_TEXT = {
    'passed': dict(
        title='Passed pawns',
        tagline='A pawn with no enemy pawn in front of it can run to the last rank.',
        why='A passed pawn has no enemy pawn on its own file or on either neighbouring file ahead of it, so only pieces '
            'can stop it. It ties down the enemy pieces, and it becomes more dangerous as the pieces come off: in the '
            'endgame a passed pawn often decides the game.',
        spot=['Check the files on both sides of the pawn, not only its own.',
              'The nearer it is to the last rank, the stronger it is.',
              'Support it with pieces and blockade the enemy\'s passed pawns.']),
    'isolated': dict(
        title='Isolated pawns',
        tagline='A pawn with no friendly pawn on a neighbouring file can never be defended by a pawn.',
        why='An isolated pawn has no friendly pawn on either side, so only pieces can guard it, and the square in front of it '
            'is a perfect post for an enemy knight. It is a weakness to attack, though it also gives its owner open '
            'lines and activity.',
        spot=['No pawn of the same colour on the two files next to it.',
              'It has to be defended by pieces for the rest of the game.',
              'Attack it, and put a piece on the square in front of it.']),
    'doubled': dict(
        title='Doubled pawns',
        tagline='Two pawns of one colour on the same file get in each other\'s way.',
        why='Doubled pawns cannot protect each other, control fewer squares and are hard to advance. They are usually a '
            'weakness, unless they bring you something, such as an open file or the bishop pair.',
        spot=['Two pawns of the same colour on one file.',
              'Look for the extra pawn that is hard to defend.',
              'Doubled pawns often come from a capture that opened a file.']),
    'backward': dict(
        title='Backward pawns',
        tagline='A pawn left behind its neighbours, with the square in front of it attacked.',
        why='A backward pawn cannot be supported by another pawn and cannot advance safely, because an enemy pawn attacks '
            'the square in front of it. Pieces must protect it, and an enemy rook or knight loves to sit on that square.',
        spot=['It is behind the pawns on the neighbouring files.',
              'An enemy pawn controls the square in front of it.',
              'The square in front of it is a long-term weakness.']),
    'openFile': dict(
        title='Open files',
        tagline='A file with no pawns is a highway for the rooks.',
        why='Rooks are strongest on open files, where they slide down the board and invade the enemy position. Put a rook '
            'on an open file early, double the rooks on it, and look for the entry squares on the seventh and eighth ranks.',
        spot=['No pawn of either colour on the file.',
              'A file with only the enemy\'s pawns on it is half-open for you.',
              'Whoever controls the open file usually has the initiative.']),
    'outpost': dict(
        title='Outposts',
        tagline='A square deep in enemy territory that your pawn defends and no enemy pawn can attack.',
        why='A knight on an outpost cannot be driven away by a pawn, and from there it attacks many squares. Look for a '
            'square on the fifth rank or beyond that one of your pawns defends, with no enemy pawn left on a neighbouring '
            'file that could ever attack it.',
        spot=['On your fifth rank or beyond.',
              'Defended by one of your own pawns.',
              'No enemy pawn on a neighbouring file can ever attack it.']),
}

DRILL_HINT = {
    'passed': 'A pawn is passed when no enemy pawn is ahead of it on its file or on the two files either side.',
    'isolated': 'Look for a pawn whose neighbouring files hold no pawn of the same colour.',
    'doubled': 'Look for two pawns of one colour on the same file, and mark both of them.',
    'backward': 'The pawn is behind its neighbours, and an enemy pawn attacks the square in front of it.',
    'openFile': 'An open file has no pawns of either colour. Tap any square on it.',
    'outpost': 'Fifth rank or beyond, defended by one of your pawns, and no enemy pawn on a neighbouring file can ever attack it.',
}


def _color_name(c):
    return c.capitalize()


def _files(targets):
    return sorted({t[0] for t in targets})


def _answer_text(concept, color, targets):
    singular, plural = NAMES[concept]
    who = _color_name(color)
    if concept == 'openFile':
        fs = ', '.join(f + '-file' for f in _files(targets))
        return f'Open: {fs}. No pawn of either colour stands on it.'
    squares = ', '.join(targets)
    word = singular if len(targets) == 1 else plural
    return f'{who}\'s {word}: {squares}.'


def _targets_for_lesson(concept, targets):
    return targets


def lessons():
    out = []
    for concept, examples in STRUCTURE.items():
        ex = examples[0]
        t = LESSON_TEXT[concept]
        out.append(dict(
            id=f'mid-{concept}', level=6, kind='concept', title=t['title'], tagline=t['tagline'],
            why=t['why'], spot=t['spot'], fen=ex['fen'], concept=concept, side=ex['color'],
            targets=ex['targets'], note=_answer_text(concept, ex['color'], ex['targets']),
            drill=f'dr-{concept}-1'))
    return out


def drills():
    out = []
    for concept, examples in STRUCTURE.items():
        singular, plural = NAMES[concept]
        for i, ex in enumerate(examples[1:], start=1):
            who = _color_name(ex['color'])
            if concept == 'openFile':
                task = 'Mark every open file (tap one square on each).'
            elif concept == 'outpost':
                task = f'Mark every outpost square for {who}\'s pieces.'
            else:
                task = f'Mark every {singular} of {who}.'
            out.append(dict(
                id=f'dr-{concept}-{i}', phase='middlegame', title=f'Spot the {plural}' + (f' ({i})' if len(examples) > 2 else ''),
                task=task, fen=ex['fen'], side='white', goal='find', max=10, hint=DRILL_HINT[concept],
                lesson=f'mid-{concept}', concept=concept, subject=ex['color'],
                explain=_answer_text(concept, ex['color'], ex['targets']), answers=ex['targets']))
    return out
