/// Time controls offered in Play: base time per side plus an increment added
/// after each of that side's moves.
enum TimeControl {
  off('No clock', 0, 0),
  blitz3('3 min + 2 s', 180000, 2000),
  blitz5('5 min', 300000, 0),
  rapid10('10 min', 600000, 0),
  rapid15('15 min + 10 s', 900000, 10000);

  const TimeControl(this.label, this.baseMs, this.incrementMs);

  final String label;
  final int baseMs;
  final int incrementMs;
}

/// A two-sided chess clock. Time is passed in, so it can be tested without
/// waiting. Sides are 0 (White) and 1 (Black), as in `piece.dart`.
///
/// The first move of the game starts the other side's clock and costs
/// nothing; after that each move pays for the time the mover used and adds
/// the increment.
class ChessClock {
  ChessClock(this.control) : _left = [control.baseMs, control.baseMs];

  final TimeControl control;
  final List<int> _left;
  int? _running;
  DateTime? _since;
  bool _stopped = false;
  bool _paused = false;

  /// Side whose clock is running, or null before the first move and after
  /// [stop].
  int? get running => _running;

  /// Milliseconds [side] has left at [now].
  int remaining(int side, DateTime now) {
    var left = _left[side];
    if (side == _running && !_stopped && !_paused) {
      left -= now.difference(_since!).inMilliseconds;
    }
    return left < 0 ? 0 : left;
  }

  /// Call when [mover] has played a move.
  void moved(int mover, DateTime now) {
    if (_stopped) return;
    if (_running != null) {
      _left[mover] = remaining(mover, now) + control.incrementMs;
    }
    _running = 1 - mover;
    _since = now;
    _paused = false;
  }

  /// Hands the turn to [side] without a move being played (a take-back): the
  /// side that was running pays for the time it used, nobody gets an
  /// increment, and [side]'s clock runs from [now].
  void giveTurnTo(int side, DateTime now) {
    if (_stopped) return;
    final running = _running;
    if (running != null) _left[running] = remaining(running, now);
    _running = side;
    _since = now;
    _paused = false;
  }

  /// Freezes the running side without switching, for work that should not
  /// cost either player time (such as the coach analysing a move).
  void pause(DateTime now) {
    final side = _running;
    if (side == null || _stopped || _paused) return;
    _left[side] = remaining(side, now);
    _paused = true;
  }

  /// Unfreezes after [pause].
  void resume(DateTime now) {
    if (!_paused) return;
    _paused = false;
    _since = now;
  }

  /// The side that has run out of time, or null.
  int? flagged(DateTime now) {
    final side = _running;
    if (side == null || _stopped) return null;
    return remaining(side, now) == 0 ? side : null;
  }

  /// Freezes both clocks (game over).
  void stop(DateTime now) {
    final side = _running;
    if (side != null && !_stopped && !_paused) _left[side] = remaining(side, now);
    _stopped = true;
  }
}

/// "4:07", or "0:09.4" in the last ten seconds.
String formatClock(int ms) {
  if (ms < 10000) {
    return '0:0${(ms / 1000).toStringAsFixed(1)}';
  }
  final total = (ms / 1000).ceil();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
