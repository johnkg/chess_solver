# Calibrates the computer levels so that each one beats the level below it by
# the gap its target Elo promises, using tool/arena.dart for the games.
#   python3 tool/tune_levels.py [out.json] [games] [time-scale] [first-level] [last-level] [gap-scale]
# Starts from the real table (Level in lib/engine/opponent.dart), keeps the
# first levels as they are, and for every later level searches for the
# temperature (and, if needed, one more ply of depth) at which it scores the
# expected share against the level below. Prints each step and writes the
# whole ladder to out.json, ready for `arena.dart ... out.json` to confirm and
# for copying into the Level enum.
# gap-scale converts a label gap into the gap that engine-versus-engine games
# should show. Self-play scores are lopsided (a one-ply deeper engine wins
# 90%+), so the whole ladder spans about 1.4 times its label range; matching
# the label gaps exactly would squeeze every level into the weakest depths.
# The default of 1.4 spreads the steps evenly over the range the engine has.
# Depth never decreases, and a deeper level
# may be noisier than the one below; the temperature only falls within a depth.
import json
import math
import re
import subprocess
import sys

LEVELS = ['Beginner', 'Novice', 'Casual', 'Intermediate', 'Club', 'Advanced', 'Expert',
          'Candidate Master', 'Master', 'International Master', 'Grandmaster']
ELO = [600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2500]

# Temperature range tried, centipawns; margin follows the temperature.
MIN_TEMP, MAX_TEMP = 3, 400
MIN_MARGIN, MAX_MARGIN = 25, 500
MARGIN_PER_TEMP = 3
DEEPEST = 10
BISECTIONS = 5


DEFAULT_GAP_SCALE = 1.4


def expected_score(gap):
    """Share of points the stronger side should win at an Elo gap."""
    return 1 / (1 + 10 ** (-gap / 400))


def margin_for(temperature):
    return max(MIN_MARGIN, min(MAX_MARGIN, MARGIN_PER_TEMP * temperature))


def current_table():
    """The settings now in the Level enum, read from opponent.dart."""
    src = open('lib/engine/opponent.dart').read()
    rows = re.findall(r"LevelSettings\(depth: (\d+), millis: (\d+), temperature: (\d+), margin: (\d+), "
                      r"bookPlies: (\d+)(?:, mateDepth: (\d+))?\)", src)
    assert len(rows) == len(LEVELS), len(rows)
    return [dict(depth=int(d), millis=int(m), temperature=int(t), margin=int(g), bookPlies=int(b),
                 mateDepth=int(x or 0)) for d, m, t, g, b, x in rows]


def score_pair(ladder, i, games, scale, path):
    """Points level i scores against level i-1 over `games` games."""
    json.dump(ladder, open(path, 'w'))
    out = subprocess.run(['dart', 'run', 'tool/arena.dart', str(games), str(scale), str(i - 1), str(i - 1), '7', path],
                         capture_output=True, text=True).stdout
    m = re.search(r'scores ([\d.]+) / (\d+)', out)
    if not m:
        raise RuntimeError(out)
    return float(m.group(1)) / int(m.group(2))


def with_level(ladder, i, **changes):
    new = [dict(x) for x in ladder]
    new[i].update(changes)
    new[i]['margin'] = margin_for(new[i]['temperature'])
    return new


def tune_level(ladder, i, games, scale, path, gap_scale):
    target = expected_score(gap_scale * (ELO[i] - ELO[i - 1]))
    prev = ladder[i - 1]
    print(f'\n{LEVELS[i]}: aim for {100 * target:.0f}% against {LEVELS[i - 1]} '
          f'(depth {prev["depth"]}, temperature {prev["temperature"]})', flush=True)

    def try_(depth, temperature):
        s = score_pair(with_level(ladder, i, depth=depth, temperature=temperature), i, games, scale, path)
        print(f'   depth {depth} temperature {temperature}: {100 * s:.0f}%', flush=True)
        return s

    # Same depth first: only a lower temperature than the level below makes it stronger.
    depth = prev['depth']
    lo, hi = MIN_TEMP, prev['temperature'] - 1   # lo = strongest, hi = weakest allowed
    if hi > lo and try_(depth, lo) >= target:
        return bisect(try_, depth, lo, hi, target)
    # Not reachable at this depth: one ply deeper, from the noisiest play down.
    depth = min(DEEPEST, prev['depth'] + 1)
    lo, hi = MIN_TEMP, MAX_TEMP
    if try_(depth, hi) >= target:
        return depth, hi          # even the noisiest deeper level is stronger than needed
    if try_(depth, lo) < target:
        return depth, lo          # cannot get that strong: the strongest this depth allows
    return bisect(try_, depth, lo, hi, target)


def bisect(try_, depth, lo, hi, target):
    """Temperature in [lo, hi] (log scale) whose score is closest to target; lower is stronger."""
    best = (abs(try_(depth, hi) - target), hi)
    for _ in range(BISECTIONS):
        mid = int(round(math.exp((math.log(lo) + math.log(hi)) / 2)))
        if mid in (lo, hi):
            break
        s = try_(depth, mid)
        best = min(best, (abs(s - target), mid))
        if s >= target:
            lo = mid             # strong enough: try a higher temperature
        else:
            hi = mid             # too weak: lower the temperature
    return depth, best[1]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'ladder.json'
    games = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.3
    first = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    last = int(sys.argv[5]) if len(sys.argv) > 5 else len(LEVELS) - 1
    gap_scale = float(sys.argv[6]) if len(sys.argv) > 6 else DEFAULT_GAP_SCALE
    ladder = current_table()
    scratch = out + '.try.json'
    for i in range(first, last + 1):
        depth, temperature = tune_level(ladder, i, games, scale, scratch, gap_scale)
        ladder = with_level(ladder, i, depth=depth, temperature=temperature)
        print(f'-> {LEVELS[i]}: depth {depth}, temperature {temperature}, margin {ladder[i]["margin"]}', flush=True)
        json.dump(ladder, open(out, 'w'), indent=1)
    print('\nladder written to', out)


if __name__ == '__main__':
    main()
