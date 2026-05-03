import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/savings_goal.dart';

class GoalItem extends StatelessWidget {
  const GoalItem({
    super.key,
    required this.goal,
    required this.saved,
    required this.icon,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  final Goal goal;
  final double saved;
  final IconData icon;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  static Color _colorForGoal(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final n = name.toLowerCase();
    if (n.contains('emergency') || n.contains('fund')) return colorScheme.primary;
    if (n.contains('car')) return colorScheme.primary.withValues(alpha: 0.7);
    if (n.contains('vacation') || n.contains('travel')) return colorScheme.primary;
    if (n.contains('home') || n.contains('house')) return colorScheme.secondary;
    if (n.contains('wedding')) return colorScheme.error.withValues(alpha: 0.7);
    if (n.contains('education') || n.contains('school')) return colorScheme.primary.withValues(alpha: 0.6);
    return colorScheme.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.target <= 0 ? 0.0 : (saved / goal.target).clamp(0.0, 1.0);
    final isComplete = saved >= goal.target;
    final color = isComplete ? Theme.of(context).colorScheme.tertiary : _colorForGoal(context, goal.name);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                    // Use trophy icon if icon is the default
                    child: icon == Icons.emoji_events
                      ? Icon(Icons.emoji_events, color: color, size: 22)
                      : Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${fmt.format(saved)} / ${fmt.format(goal.target)}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.12)),
              ),
          ],
        ),
      ),
    );
  }
}
