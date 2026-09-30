import 'package:flutter_test/flutter_test.dart';
import 'package:pdiot/models/prediction.dart';
import 'package:pdiot/services/activity_history.dart';

void main() {
  final start = DateTime(2026, 9, 30, 12);
  const walk = Prediction('walking', .8);
  const breath = Prediction('breathing', .9);

  test('warm-up nulls and staggered model readiness are safe', () {
    final h = ActivityHistory();
    h.update(start, null, null);
    h.update(start.add(const Duration(milliseconds: 100)), null, breath);
    h.update(start.add(const Duration(milliseconds: 200)), walk, breath);
    expect(h.milliseconds['2026-09-30'], {'Signal: breathing': 100});
  });

  test(
      'unchanged labels accumulate sub-second updates despite varying confidence',
      () {
    final h = ActivityHistory();
    for (var i = 0; i <= 10; i++) {
      h.update(start.add(Duration(milliseconds: i * 100)),
          Prediction('walking', .7 + i / 100), breath);
    }
    expect(h.milliseconds['2026-09-30'],
        {'Activity: walking': 1000, 'Signal: breathing': 1000});
  });

  test('a transition credits the previous class', () {
    final h = ActivityHistory();
    h.update(start, walk, null);
    h.update(start.add(const Duration(seconds: 1)),
        const Prediction('running', .9), null);
    h.update(start.add(const Duration(seconds: 2)), null, null);
    expect(h.milliseconds['2026-09-30'],
        {'Activity: walking': 1000, 'Activity: running': 1000});
  });

  test('midnight splits time between dates', () {
    final h = ActivityHistory();
    h.update(DateTime(2026, 9, 30, 23, 59, 59, 500), walk, null);
    h.update(DateTime(2026, 10, 1, 0, 0, 0, 500), walk, null);
    expect(h.milliseconds['2026-09-30']!['Activity: walking'], 500);
    expect(h.milliseconds['2026-10-01']!['Activity: walking'], 500);
  });

  test(
      'disconnect, long gaps and uncertain predictions do not add guessed time',
      () {
    final h = ActivityHistory();
    h.update(start, walk, null);
    h.update(start.add(const Duration(minutes: 1)), walk, null);
    expect(h.milliseconds, isEmpty);
    h.resetSession();
    h.update(start.add(const Duration(minutes: 2)),
        const Prediction('walking', .1, uncertain: true), null);
    h.update(start.add(const Duration(minutes: 2, seconds: 1)), null, null);
    expect(h.milliseconds, isEmpty);
  });
}
