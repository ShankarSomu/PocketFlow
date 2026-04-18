import 'package:flutter/material.dart';
import 'package:pocket_flow/core/formatters.dart';
import 'package:pocket_flow/core/color_extensions.dart';
import 'package:pocket_flow/widgets/cards/cards.dart';
import 'package:pocket_flow/utils/calculation_helpers.dart';

/// Example widget showing how to use the new utilities
/// This demonstrates best practices for the refactored codebase
class ExampleRefactoredWidget extends StatelessWidget {
  final double income;
  final double expenses;
  final DateTime lastTransaction;
  final double budgetAmount;
  final double budgetSpent;

  const ExampleRefactoredWidget({
    super.key,
    required this.income,
    required this.expenses,
    required this.lastTransaction,
    required this.budgetAmount,
    required this.budgetSpent,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Use context extension for quick theme access
    final colors = context.colors;
    final textTheme = context.textTheme;
    final isDark = context.isDarkMode;

    // ✅ Use calculation helpers instead of inline math
    final savingsRate = calculateSavingsRate(income, expenses);
    final budgetCompliance = calculateBudgetCompliance(budgetSpent, budgetAmount);
    final remaining = calculateRemainingBudget(budgetAmount, budgetSpent);
    final isOverBudget = isBudgetOverLimit(budgetSpent, budgetAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Refactored Widget'),
        backgroundColor: colors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Use StandardCard instead of custom Container+BoxDecoration
          StandardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Summary',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // ✅ Use CurrencyFormatter instead of NumberFormat instances
                _InfoRow(
                  label: 'Income',
                  value: CurrencyFormatter.format(income),
                  // ✅ Use color extensions for opacity
                  valueColor: colors.tertiary,
                ),
                _InfoRow(
                  label: 'Expenses',
                  value: CurrencyFormatter.format(expenses),
                  valueColor: colors.error,
                ),
                const Divider(height: 32),
                _InfoRow(
                  label: 'Savings Rate',
                  // ✅ Use NumberFormatter for percentages
                  value: NumberFormatter.percentage(savingsRate * 100),
                  valueColor: savingsRate >= 0.2 ? colors.tertiary : colors.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Use GradientCard for visual appeal
          GradientCard.emerald(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.savings, color: colors.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Savings Goal',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  // ✅ Use formatters for consistent currency display
                  'You saved ${CurrencyFormatter.formatCompact(income - expenses)} this month!',
                  // ✅ Use color helper for opacity
                  style: TextStyle(color: colors.onPrimary.lighter),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Use OutlinedCard for variety
          OutlinedCard(
            borderColor: isOverBudget ? colors.error : colors.outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget Status',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: budgetCompliance.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: isOverBudget ? colors.error : colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      // ✅ No decimals for budget amounts
                      CurrencyFormatter.formatNoDecimals(budgetSpent),
                      style: TextStyle(
                        color: isOverBudget ? colors.error : colors.onSurface,
                      ),
                    ),
                    Text(
                      'of ${CurrencyFormatter.formatNoDecimals(budgetAmount)}',
                      // ✅ Use subtle opacity
                      style: TextStyle(color: colors.onSurface.subtle),
                    ),
                  ],
                ),
                if (isOverBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    // ✅ Use InfoCard for status messages
                    child: InfoCard.error(
                      context,
                      message: 'Over budget by ${CurrencyFormatter.format(remaining.abs())}',
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Use CompactCard for minimal padding
          CompactCard(
            // ✅ Use color helper for very faint background
            backgroundColor: colors.primary.veryFaint,
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  // ✅ Use DateFormatter for consistent date display
                  'Last transaction: ${DateFormatter.relative(lastTransaction)}',
                  style: TextStyle(
                    fontSize: 12,
                    // ✅ Use subtle opacity for secondary text
                    color: colors.onSurface.subtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Use InfoCard variants for different message types
          InfoCard.info(
            message: 'Budget tracking helps you stay on top of your finances',
          ),
          const SizedBox(height: 8),
          
          if (budgetCompliance < 0.1)
            InfoCard.warning(
              context,
              message: 'You\'re near your budget limit!',
            ),
        ],
      ),
    );
  }
}

/// Helper widget for info rows
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ Use context extension
          Text(
            label,
            style: TextStyle(color: context.colors.onSurface.subtle),
          ),
          Text(
            value,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================
// COMPARISON: OLD vs NEW
// ========================================

// ❌ OLD WAY (Before Refactoring)
class OldWayExample extends StatelessWidget {
  final double amount;
  final DateTime date;

  const OldWayExample({
    super.key,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Use static formatters from core/formatters.dart
    return Container(
      // ❌ Manual BoxDecoration
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ❌ Verbose opacity calls
          Text(
            DateFormatter.medium(date),
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          Text(
            CurrencyFormatter.formatNoDecimals(amount),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

// ✅ NEW WAY (After Refactoring)
class NewWayExample extends StatelessWidget {
  final double amount;
  final DateTime date;

  const NewWayExample({
    super.key,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ No formatter instances needed!
    return StandardCard(
      child: Column(
        children: [
          // ✅ Clean, readable code
          Text(
            DateFormatter.medium(date),
            style: TextStyle(color: context.colors.onSurface.subtle),
          ),
          Text(
            CurrencyFormatter.formatNoDecimals(amount),
            style: context.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
