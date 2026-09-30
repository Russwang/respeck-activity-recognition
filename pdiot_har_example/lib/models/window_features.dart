import 'dart:math';

/// Match Python's population standard deviation (ddof=0) and channel order.
List<List<double>> meanFeatures(List<List<double>> samples) {
  if (samples.isEmpty ||
      samples.any((s) => s.length != 3 || s.any((v) => !v.isFinite))) {
    throw ArgumentError('Expected a non-empty window of finite x/y/z samples');
  }
  final mean = List<double>.filled(3, 0);
  final std = List<double>.filled(3, 0);
  for (final sample in samples) {
    for (var axis = 0; axis < 3; axis++) {
      mean[axis] += sample[axis] / samples.length;
    }
  }
  for (final sample in samples) {
    for (var axis = 0; axis < 3; axis++) {
      std[axis] += pow(sample[axis] - mean[axis], 2) / samples.length;
    }
  }
  for (var axis = 0; axis < 3; axis++) {
    std[axis] = sqrt(std[axis]) + 1e-6;
  }
  return samples
      .map((sample) => [
            for (var axis = 0; axis < 3; axis++)
              (sample[axis] - mean[axis]) / std[axis],
            ...mean,
          ])
      .toList();
}
