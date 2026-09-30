import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdiot/history.dart';

void main() {
  testWidgets('History renders millisecond totals as seconds and minutes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: HistoryPage(stats: {
      '2026-09-30': {'Activity: running': 90500},
    })));
    await tester.tap(find.text('2026-09-30'));
    await tester.pumpAndSettle();
    expect(find.text('Activity: running'), findsOneWidget);
    expect(find.text('90.5s (1.5 min)'), findsOneWidget);
  });
}
