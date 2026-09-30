import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/prediction.dart';
import '../models/window_features.dart';

class WindowClassifier {
  final String manifestAsset;
  final double threshold;
  Interpreter? _interpreter;
  List<String> _labels = [];
  final List<List<double>> _samples = [];
  int windowSize = 120;
  String? error;

  WindowClassifier(this.manifestAsset, {this.threshold = 0});

  Future<bool> initialize() async {
    dispose();
    try {
      final manifest = jsonDecode(await rootBundle.loadString(manifestAsset))
          as Map<String, dynamic>;
      final shape = List<int>.from(manifest['input_shape']);
      final output = List<int>.from(manifest['output_shape']);
      _labels = List<String>.from(manifest['labels']);
      if (shape.length != 3 ||
          shape[0] != 1 ||
          shape[2] != 6 ||
          manifest['preprocessing'] != 'window_standardize_plus_mean' ||
          manifest['dtype'] != 'float32' ||
          manifest['epsilon'] != 1e-6 ||
          shape[1] <= 0 ||
          !listEquals(output, [1, _labels.length])) {
        throw StateError('Unsupported model manifest: $manifestAsset');
      }
      windowSize = shape[1];
      final interpreter =
          await Interpreter.fromAsset(manifest['asset'] as String);
      _interpreter = interpreter;
      if (!listEquals(interpreter.getInputTensor(0).shape, shape) ||
          !listEquals(interpreter.getOutputTensor(0).shape, output) ||
          interpreter.getInputTensor(0).type != TensorType.float32 ||
          interpreter.getOutputTensor(0).type != TensorType.float32) {
        throw StateError('Model tensors do not match $manifestAsset');
      }
      error = null;
      return true;
    } catch (e) {
      error = e.toString();
      debugPrint('Model initialization failed: $error');
      dispose();
      return false;
    }
  }

  void addSample(double x, double y, double z) {
    if (![x, y, z].every((v) => v.isFinite)) {
      clearBuffer();
      return;
    }
    _samples.add([x, y, z]);
    if (_samples.length > windowSize) _samples.removeAt(0);
  }

  bool get hasEnoughSamples => _samples.length == windowSize;
  int get bufferSize => _samples.length;

  Prediction? predict() {
    if (_interpreter == null || !hasEnoughSamples) return null;
    try {
      final output = [List<double>.filled(_labels.length, 0)];
      _interpreter!.run([meanFeatures(_samples)], output);
      final scores = output.first;
      if (scores.any((v) => !v.isFinite)) {
        throw StateError('Non-finite model output');
      }
      var best = 0;
      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > scores[best]) best = i;
      }
      return Prediction(_labels[best], scores[best],
          uncertain: scores[best] <= threshold);
    } catch (e) {
      debugPrint('Prediction failed: $e');
      return null;
    }
  }

  void clearBuffer() => _samples.clear();

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    clearBuffer();
  }
}
