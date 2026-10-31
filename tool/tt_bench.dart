// ignore_for_file: avoid_print
// Nodes and time to a fixed depth, pruning off (table on) against pruning on.
//   dart run tool/tt_bench.dart [depth]
import 'package:chess_solver/engine/engine.dart';
import 'package:chess_solver/engine/position.dart';

const fens = [
  'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
  'r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 7',
  'r2q1rk1/pp2bppp/2n1pn2/3p4/3P4/2NBPN2/PP3PPP/R1BQ1RK1 w - - 0 9',
  '8/5pk1/6p1/8/3R4/6P1/5PK1/3r4 w - - 0 40',
  '2r2rk1/pp3ppp/3q1n2/3p4/3P4/2N1PQ2/PP3PPP/2R2RK1 w - - 0 18',
];

void main(List<String> args) {
  final depth = args.isNotEmpty ? int.parse(args[0]) : 5;
  var nOff = 0, nOn = 0, tOff = 0, tOn = 0;
  for (final fen in fens) {
    final pos = Position.fromFen(fen);
    final sw = Stopwatch();
    sw.start();
    final off = Searcher(pruning: false).search(pos, maxDepth: depth, millis: 600000)!;
    final a = sw.elapsedMilliseconds;
    sw
      ..reset()
      ..start();
    final on = Searcher().search(pos, maxDepth: depth, millis: 600000)!;
    final b = sw.elapsedMilliseconds;
    nOff += off.nodes;
    nOn += on.nodes;
    tOff += a;
    tOn += b;
    print('old ${off.best.$1} ${off.best.$2} n=${off.nodes} ${a}ms | '
        'new ${on.best.$1} ${on.best.$2} n=${on.nodes} ${b}ms');
  }
  print('total nodes off=$nOff on=$nOn  time off=${tOff}ms on=${tOn}ms');
}
