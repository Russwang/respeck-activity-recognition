import '../models/prediction.dart';

/// Millisecond totals preserve sub-second BLE updates. Only observed intervals
/// are counted; long gaps, disconnects and background time are excluded.
class ActivityHistory {
  final Map<String, Map<String, int>> milliseconds;
  DateTime? _last;
  Prediction? _activity;
  Prediction? _social;

  ActivityHistory([Map<String, Map<String, int>>? initial])
      : milliseconds = initial ?? {};

  void resetSession() {
    _last = null;
    _activity = null;
    _social = null;
  }

  void update(DateTime now, Prediction? activity, Prediction? social) {
    final last = _last;
    if (last != null &&
        now.isAfter(last) &&
        now.difference(last) <= const Duration(seconds: 5)) {
      var start = last;
      while (start.isBefore(now)) {
        final midnight = DateTime(start.year, start.month, start.day + 1);
        final end = now.isBefore(midnight) ? now : midnight;
        final key =
            '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
        for (final entry
            in {'Activity': _activity, 'Signal': _social}.entries) {
          final prediction = entry.value;
          if (prediction == null || prediction.uncertain) continue;
          final totals = milliseconds.putIfAbsent(key, () => {});
          final label = '${entry.key}: ${prediction.label}';
          totals[label] =
              (totals[label] ?? 0) + end.difference(start).inMilliseconds;
        }
        start = end;
      }
    }
    _last = now;
    _activity = activity;
    _social = social;
  }
}
