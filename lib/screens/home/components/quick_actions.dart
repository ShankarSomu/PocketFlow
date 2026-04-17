import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class QuickActions extends StatelessWidget {
  final void Function(String feature) onAction;
  const QuickActions({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'New Transaction', 'icon': Icons.add_rounded, 'feature': 'Add Transaction'},
      {'label': 'Budget Summary', 'icon': Icons.pie_chart_outline, 'feature': 'Budget Summary'},
      {'label': 'Savings Goal', 'icon': Icons.flag_outlined, 'feature': 'Savings Goal'},
    ];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions.map((action) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => onAction(action['feature'] as String),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action['icon'] as IconData, size: 20, color: AppTheme.slate900),
                      const SizedBox(height: 6),
                      Text(
                        action['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppTheme.slate900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
