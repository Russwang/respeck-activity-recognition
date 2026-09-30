import 'models/prediction.dart';
import 'services/window_classifier.dart';

/// Compatibility facade; model configuration lives beside the bundled model.
class HARService {
  static final _classifier =
      WindowClassifier('assets/physical.json', threshold: 0.2);
  static int get windowSize => _classifier.windowSize;
  static Future<bool> initialize() => _classifier.initialize();
  static void addSample(double x, double y, double z) =>
      _classifier.addSample(x, y, z);
  static bool hasEnoughSamples() => _classifier.hasEnoughSamples;
  static Prediction? predict() => _classifier.predict();
  static int getBufferSize() => _classifier.bufferSize;
  static void clearBuffer() => _classifier.clearBuffer();
  static void dispose() => _classifier.dispose();
}
