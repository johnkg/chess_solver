import 'package:chess_solver/ui/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('misses are counted, relieved, saved and reloaded', () async {
    final a = ProgressStore();
    await a.recordMiss('fork');
    await a.recordMiss('fork');
    await a.recordMiss('mate');
    await a.relieve('mate');
    await a.relieve('pin'); // never missed: no-op
    expect(a.missed, {'fork': 2});

    final b = ProgressStore();
    await b.load();
    expect(b.missed, {'fork': 2});

    await b.reset();
    expect(b.missed, isEmpty);
  });
}
