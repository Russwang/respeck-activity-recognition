import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  final Map<String, Map<String, int>> stats;

  const HistoryPage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final days = stats.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final map = stats[day]!;
          return ExpansionTile(
            title: Text(day),
            children: map.entries.map((e) {
              final minutes = (e.value / 60000).toStringAsFixed(1);
              return ListTile(
                title: Text(e.key),
                subtitle: Text(
                    "${(e.value / 1000).toStringAsFixed(1)}s ($minutes min)"),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
