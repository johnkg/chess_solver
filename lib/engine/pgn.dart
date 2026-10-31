import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'san.dart';

/// A game as stored in PGN: tags, the moves, and how it ended.
class PgnGame {
  const PgnGame({required this.headers, required this.moves, required this.result});

  /// Tag pairs such as `White` and `Event`.
  final Map<String, String> headers;

  /// The moves from the start position (or from the `FEN` tag).
  final List<Move> moves;

  /// "1-0", "0-1", "1/2-1/2" or "*".
  final String result;

  String get white => headers['White'] ?? 'White';
  String get black => headers['Black'] ?? 'Black';

  /// Where the game starts.
  Position get start {
    final fen = headers['FEN'];
    return fen == null ? Position.start() : Position.fromFen(fen);
  }

  /// The positions before each move, then the final one.
  List<Position> get positions {
    final out = <Position>[start];
    for (final m in moves) {
      out.add(out.last.makeMove(m));
    }
    return out;
  }
}

/// Result string for a finished game from the outcome, "*" while unfinished.
String pgnResult(Position end) {
  if (end.isCheckmate) return end.turn == white ? '0-1' : '1-0';
  if (end.isStalemate) return '1/2-1/2';
  return '*';
}

/// PGN result tag for a [score] earned by [player]: "1-0", "0-1", "1/2-1/2",
/// or "*" while the game is unfinished.
String pgnResultForScore(double? score, int player) {
  if (score == null) return '*';
  if (score == 0.5) return '1/2-1/2';
  final playerWon = score == 1;
  return playerWon == (player == white) ? '1-0' : '0-1';
}

/// PGN date tag, "2026.10.31".
String pgnDate(DateTime when) =>
    '${when.year}.${when.month.toString().padLeft(2, '0')}.${when.day.toString().padLeft(2, '0')}';

/// PGN text for [moves] played from [start]. [headers] are written first (the
/// seven-tag roster in order, then any others); [result] defaults to what the
/// final position says.
String toPgn(
  List<Move> moves, {
  Position? start,
  Map<String, String> headers = const {},
  String? result,
}) {
  final first = start ?? Position.start();
  var pos = first;
  final tokens = <String>[];
  for (final m in moves) {
    final number = pos.turn == white
        ? '${pos.fullmove}. '
        : (tokens.isEmpty ? '${pos.fullmove}... ' : '');
    tokens.add('$number${san(pos, m)}');
    pos = pos.makeMove(m);
  }
  final res = result ?? pgnResult(pos);
  final tags = <String, String>{
    'Event': 'Casual game',
    'Site': 'Chess Technique Teacher',
    'Date': '????.??.??',
    'Round': '-',
    'White': '?',
    'Black': '?',
    ...headers,
    'Result': res,
  };
  if (start != null && first.toFen() != Position.start().toFen()) {
    tags['SetUp'] = '1';
    tags['FEN'] = first.toFen();
  }
  const roster = ['Event', 'Site', 'Date', 'Round', 'White', 'Black', 'Result'];
  final keys = [...roster, ...tags.keys.where((k) => !roster.contains(k))];
  final out = StringBuffer();
  for (final k in keys) {
    out.writeln('[$k "${tags[k]!.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"]');
  }
  out.writeln();
  // Wrap the movetext at 80 columns, as PGN exporters do.
  var line = '';
  for (final t in [...tokens, res]) {
    if (line.isNotEmpty && line.length + 1 + t.length > 80) {
      out.writeln(line);
      line = t;
    } else {
      line = line.isEmpty ? t : '$line $t';
    }
  }
  out.writeln(line);
  return out.toString();
}

/// Reads the first game in [text]. Comments, variations, NAGs and move
/// numbers are skipped. Throws [FormatException] naming the move that does
/// not fit, so the caller can tell the user.
PgnGame parsePgn(String text) {
  final headers = <String, String>{};
  final tag = RegExp(r'^\s*\[(\w+)\s+"((?:[^"\\]|\\.)*)"\]\s*$');
  final body = StringBuffer();
  var seenMoves = false;
  for (final raw in text.replaceAll('\r', '').split('\n')) {
    final m = tag.firstMatch(raw);
    if (m != null && !seenMoves) {
      headers[m.group(1)!] = m.group(2)!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    } else if (raw.trim().isNotEmpty) {
      seenMoves = true;
      body.write('$raw\n');
    }
  }
  var movetext = body.toString();
  movetext = movetext.replaceAll(RegExp(r'\{[^}]*\}'), ' '); // comments
  movetext = movetext.replaceAll(RegExp(r';[^\n]*'), ' ');
  var depth = 0;
  final flat = StringBuffer();
  for (final ch in movetext.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      flat.write(ch);
    }
  }
  var pos = headers['FEN'] == null ? Position.start() : Position.fromFen(headers['FEN']!);
  final moves = <Move>[];
  var result = headers['Result'] ?? '*';
  for (final token in flat.toString().split(RegExp(r'\s+'))) {
    if (token.isEmpty || token.startsWith(r'$')) continue;
    if (const {'1-0', '0-1', '1/2-1/2', '*'}.contains(token)) {
      result = token;
      break;
    }
    final name = token.replaceFirst(RegExp(r'^\d+\.+'), '');
    if (name.isEmpty) continue;
    final move = moveFromSan(pos, name);
    if (move == null) {
      throw FormatException(
        'Move ${moves.length + 1} ("$name") is not legal here.',
      );
    }
    moves.add(move);
    pos = pos.makeMove(move);
  }
  if (moves.isEmpty) throw const FormatException('No moves found.');
  return PgnGame(headers: headers, moves: moves, result: result);
}
