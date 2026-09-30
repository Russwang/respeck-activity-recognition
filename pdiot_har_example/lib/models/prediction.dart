/// A class identity is separate from its changing score and display text.
class Prediction {
  final String label;
  final double confidence;
  final bool uncertain;

  const Prediction(this.label, this.confidence, {this.uncertain = false});

  @override
  String toString() =>
      '${uncertain ? "Uncertain: " : ""}$label (${(confidence * 100).toStringAsFixed(1)}%)';
}
