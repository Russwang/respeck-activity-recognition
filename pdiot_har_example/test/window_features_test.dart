import 'package:flutter_test/flutter_test.dart';
import 'package:pdiot/models/window_features.dart';

void main() {
  test(
      'constant input retains mean and produces finite zero normalized channels',
      () {
    final out = meanFeatures(List.generate(120, (_) => [1.0, -2.0, 3.0]));
    expect(out.length, 120);
    for (final row in out) {
      for (var i = 0; i < 3; i++) {
        expect(row[i], closeTo(0, 1e-7));
        expect(row[i + 3], closeTo([1.0, -2.0, 3.0][i], 1e-7));
      }
    }
  });
  test('matches population standard deviation and Python channel order', () {
    final out = meanFeatures([
      [1, 2, 3],
      [3, 4, 5]
    ]);
    for (var axis = 0; axis < 3; axis++) {
      expect(out[0][axis], closeTo(-1 / 1.000001, 1e-9));
      expect(out[1][axis], closeTo(1 / 1.000001, 1e-9));
      expect(out[0][axis + 3], axis + 2.0);
    }
  });
  test('rejects empty, malformed and non-finite samples', () {
    expect(() => meanFeatures([]), throwsArgumentError);
    expect(
        () => meanFeatures([
              [1, 2]
            ]),
        throwsArgumentError);
    expect(
        () => meanFeatures([
              [1, double.nan, 3]
            ]),
        throwsArgumentError);
  });
}
