import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/savings_goal.dart';
class SavingsOverviewCard extends StatelessWidget {
  const SavingsOverviewCard({required this.goals, required this.fmt, super.key});
  final List<Goal> goals;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Savings Goals',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...goals.take(3).map((g) {
            if (g == null) return const SizedBox.shrink();
            final saved = 0.0; // TODO: Replace with actual computation if available
            final progress = g.target > 0 ? (saved / g.target).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(g.name, style: const TextStyle(fontSize: 12)),
                      Text('${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  Text('${fmt.format(saved)} of ${fmt.format(g.target)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            );
          }),
          if (goals.length > 3)
            Text('+ ${goals.length - 3} more',
                style:
                    TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}

