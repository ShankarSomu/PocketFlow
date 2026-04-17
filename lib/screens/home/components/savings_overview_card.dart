import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/savings_goal.dart';

class SavingsOverviewCard extends StatelessWidget {
  final List<SavingsGoal> goals;
  final NumberFormat fmt;
  const SavingsOverviewCard(
      {super.key, required this.goals, required this.fmt});

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
          ...goals.take(3).map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(g.name,
                                style: const TextStyle(fontSize: 12)),
                            Text(
                                '${(g.progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(
                        value: g.progress,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      Text(
                          '${fmt.format(g.saved)} of ${fmt.format(g.target)}',
                          style: TextStyle(
                              fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    ]),
              )),
          if (goals.length > 3)
            Text('+ ${goals.length - 3} more',
                style:
                    TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}
