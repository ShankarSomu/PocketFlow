import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/account.dart';
import '../../../models/recurring_transaction.dart';
import '../../../models/savings_goal.dart'; // Contains Goal
import '../../../theme/app_color_scheme.dart';
import 'recurring_history_sheet.dart';

/// Single row in the recurring list.
/// Tap → edit form.  Long-press or history icon → transaction history sheet.
class RecurringItemTile extends StatelessWidget {
  const RecurringItemTile({
    required this.item,
    required this.accounts,
    required this.goals,
    required this.fmt,
    required this.showDivider,
    required this.onEdit,
    required this.onToggle,
    super.key,
  });

  final RecurringTransaction item;
  final List<Account> accounts;
  final List<Goal> goals;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  static Color _colorForType(BuildContext context, String type) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'income':
        return cs.tertiary;
      case 'transfer':
        return cs.primary;
      case 'goal':
        return cs.secondary;
      default:
        return cs.primary.withValues(alpha: 0.7);
    }
  }

  static IconData _iconForType(String type, String category) {
    if (type == 'income') return Icons.arrow_downward_rounded;
    if (type == 'transfer') return Icons.swap_horiz_rounded;
    if (type == 'goal') return Icons.savings_rounded;
    final c = category.toLowerCase();
    if (c.contains('netflix') || c.contains('streaming')) return Icons.subscriptions_rounded;
    if (c.contains('spotify') || c.contains('music')) return Icons.music_note_rounded;
    if (c.contains('gym') || c.contains('fitness')) return Icons.fitness_center_rounded;
    if (c.contains('phone') || c.contains('mobile')) return Icons.phone_android_rounded;
    if (c.contains('internet') || c.contains('wifi')) return Icons.wifi_rounded;
    if (c.contains('insurance')) return Icons.shield_rounded;
    if (c.contains('food') || c.contains('dining')) return Icons.restaurant_rounded;
    if (c.contains('rent') || c.contains('mortgage')) return Icons.home_rounded;
    return Icons.repeat_rounded;
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecurringHistorySheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(context, item.type);
    final icon = _iconForType(item.type, item.category);
    final account = accounts.where((a) => a.id == item.accountId).firstOrNull;
    final toAccount = accounts.where((a) => a.id == item.toAccountId).firstOrNull;
    final goal = goals.where((g) => g.id == item.goalId).firstOrNull;
    final dueStr = DateFormat('MMM d').format(item.nextDueDate);
    final freq = item.frequency[0].toUpperCase() + item.frequency.substring(1);

    // Build subtitle: frequency + next due + account info
    String subtitle = '$freq  ·  Next $dueStr';
    if (item.type == 'transfer' && account != null && toAccount != null) {
      subtitle += '  ·  ${account.name} → ${toAccount.name}';
    } else if (item.type == 'goal' && goal != null) {
      subtitle += '  ·  ${goal.name}';
      if (account != null) subtitle += ' from ${account.name}';
    } else if (account != null) {
      subtitle += '  ·  ${account.name}';
    }

    // Start date chip
    final startStr = item.startDate != null
        ? 'Since ${DateFormat('MMM yyyy').format(item.startDate!)}'
        : null;

    return InkWell(
      onTap: onEdit,
      onLongPress: () => _showHistory(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: item.isActive ? 0.12 : 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: item.isActive
                        ? color
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item.isActive
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount + controls column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.type == 'income' ? '+' : '-'}${fmt.format(item.amount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: item.isActive
                            ? (item.type == 'income'
                                ? Theme.of(context).extension<AppColorScheme>()!.success
                                : Theme.of(context).colorScheme.onSurface)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // History button
                        GestureDetector(
                          onTap: () => _showHistory(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.history_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Pause/Resume
                        GestureDetector(
                          onTap: onToggle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? Theme.of(context).colorScheme.secondaryContainer
                                  : Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.isActive ? 'Pause' : 'Resume',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.isActive
                                    ? Theme.of(context).colorScheme.onSecondaryContainer
                                    : Theme.of(context).colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Start date + note row
            if (startStr != null || (item.note != null && item.note!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (startStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          startStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Text(
                        item.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 56),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
