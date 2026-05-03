import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/savings_goal.dart';
import 'goal_item.dart';

class GoalsSection extends StatelessWidget {
  const GoalsSection({
    super.key,
    required this.label,
    required this.goals,
    required this.iconFor,
    required this.fmt,
    required this.onTap,
    required this.getSaved,
  });
  final String label;
  final List<Goal> goals;
  final IconData Function(String) iconFor;
  final NumberFormat fmt;
  final void Function(Goal) onTap;
  final double Function(Goal) getSaved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: goals.asMap().entries.map((e) {
              final isLast = e.key == goals.length - 1;
              final saved = getSaved(e.value);
              return GoalItem(
                goal: e.value,
                saved: saved,
                icon: iconFor(e.value.name),
                fmt: fmt,
                showDivider: !isLast,
                onTap: () => onTap(e.value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
