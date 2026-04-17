import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpendingCard extends StatelessWidget {
  final Map<String, double> categorySpend;
  final NumberFormat fmt;
  const SpendingCard(
      {super.key, required this.categorySpend, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sorted = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        categorySpend.values.fold(0.0, (s, v) => s + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Spending by Category',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...sorted.take(5).map((e) {
            final ratio =
                total > 0 ? (e.value / total).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Text(e.key,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 5,
                  child: LinearProgressIndicator(
                    value: ratio,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(fmt.format(e.value),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}
