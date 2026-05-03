import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../theme/app_color_scheme.dart';
import '../../../widgets/ui/panel.dart';
import '../../savings/savings_screen.dart'; // Contains GoalsScreen
import '../../shared/shared.dart';
import '../../transactions/transactions_screen.dart';

/// Smart insights widget showing AI-generated financial insights
class HomeSmartInsights extends StatelessWidget {

  const HomeSmartInsights({
    required this.categorySpend, required this.budgets, required this.income, required this.expenses, required this.savingsRate, super.key,
  });
  final Map<String, double> categorySpend;
  final List<Budget> budgets;
  final double income;
  final double expenses;
  final double savingsRate;

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  List<Map<String, dynamic>> _generateInsights(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorScheme>()!;
    final list = <Map<String, dynamic>>[];

    // Top spending category
    if (categorySpend.isNotEmpty) {
      final top = categorySpend.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      final pct = expenses > 0 ? (top.value / expenses * 100).round() : 0;
      list.add({
        'icon': Icons.pie_chart_rounded,
        'color': appColors.warning,
        'message':
            '${_titleCase(top.key)} is $pct% of your expenses this month.',
        'cta': 'Details',
        'route': 'expense',
      });
    }

    // Budget exceeded
    if (list.length < 2) {
      for (final b in budgets) {
        final spent = categorySpend[b.category] ?? 0;
        if (spent > b.limit) {
          final over = ((spent - b.limit) / b.limit * 100).round();
          list.add({
            'icon': Icons.warning_amber_rounded,
            'color': appColors.error,
            'message':
                '${_titleCase(b.category)} budget exceeded by $over%.',
            'cta': 'Review',
            'route': 'expense',
          });
          break;
        }
      }
    }

    // Savings insight
    if (list.length < 2 && income > 0) {
      final sz = (savingsRate * 100).round();
      final good = savingsRate >= 0.2;
      list.add({
        'icon': Icons.savings_rounded,
        'color': good ? appColors.success : appColors.primaryVariant,
        'message': good
            ? 'Great! You\'re saving $sz% of income this month.'
            : 'Savings at $sz%. Aim for 20% to build a safety net.',
        'cta': 'Goals',
        'route': 'savings',
      });
    }

    if (list.isEmpty) {
      list.add({
        'icon': Icons.lightbulb_rounded,
        'color': appColors.primary,
        'message': 'Add transactions to unlock personalized insights.',
        'cta': 'Start',
        'route': 'none',
      });
    }

    return list.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights(context);

    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.primary, size: 15),
              const SizedBox(width: 6),
              Text('Smart Insights',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ...insights.map((insight) {
            final color = insight['color'] as Color;
            final route = insight['route'] as String? ?? 'none';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(insight['icon'] as IconData,
                        color: color, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(insight['message'] as String,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8)))),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (route == 'income' || route == 'expense') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TransactionsScreen(
                                    initialFilterType: route)));
                      } else if (route == 'savings') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GoalsScreen()));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TransactionsScreen()));
                      }
                    },
                    child: Text(insight['cta'] as String,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

