import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class SpendingSnapshot extends StatelessWidget {

  const SpendingSnapshot({
    required this.income, required this.expenses, required this.categorySpend, required this.fmt, required this.selectedIndex, required this.onCategorySelected, super.key,
  });
  final double income;
  final double expenses;
  final Map<String, double> categorySpend;
  final NumberFormat fmt;
  final int selectedIndex;
  final ValueChanged<int> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final ratio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSpend = categorySpend.values.fold(0.0, (sum, value) => sum + value);
    final selectedIdx = selectedIndex >= 0 && selectedIndex < sortedCategories.length
        ? selectedIndex
        : 0;
    final selectedCategory = sortedCategories.isNotEmpty
        ? sortedCategories[selectedIdx]
        : null;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending Snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SmallStat(label: 'Income', value: fmt.format(income), color: AppTheme.emerald)),
              const SizedBox(width: 12),
              Expanded(child: SmallStat(label: 'Expenses', value: fmt.format(expenses), color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio, 
                minHeight: 10, 
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.slate200, 
                valueColor: const AlwaysStoppedAnimation(AppTheme.error)
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(ratio * 100).toStringAsFixed(0)}% of income spent', style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
          const SizedBox(height: 20),
          const Text('Spending by Category', style: TextStyle(fontSize: 14, color: AppTheme.slate700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: selectedCategory != null && totalSpend > 0 ? (selectedCategory.value / totalSpend).clamp(0.0, 1.0) : 0.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 18,
                                    backgroundColor: AppTheme.slate200,
                                    valueColor: const AlwaysStoppedAnimation(AppTheme.blue),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedCategory?.key ?? 'No data',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      selectedCategory != null ? fmt.format(selectedCategory.value) : '--',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedCategory != null && totalSpend > 0
                                          ? '${((selectedCategory.value / totalSpend) * 100).toStringAsFixed(0)}%'
                                          : '0%',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedCategory != null)
                      Text(
                        'Selected: ${selectedCategory.key}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slate700),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedCategories
                      .take(4)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final label = entry.value.key;
                    final value = entry.value.value;
                    final percent = totalSpend > 0 ? (value / totalSpend).clamp(0.0, 1.0) : 0.0;
                    final isSelected = index == selectedIndex;
                    return GestureDetector(
                      onTap: () => onCategorySelected(index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.indigo.withValues(alpha: 0.12) : AppTheme.slate50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? AppTheme.indigo.withValues(alpha: 0.3) : AppTheme.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.indigo : AppTheme.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: AppTheme.slate900)),
                                  const SizedBox(height: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.indigo.withValues(alpha: 0.3), width: 0.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 7,
                                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : AppTheme.slate200,
                                        valueColor: const AlwaysStoppedAnimation(AppTheme.indigo),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(fmt.format(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SmallStat extends StatelessWidget {
  const SmallStat({required this.label, required this.value, required this.color, super.key});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
        ],
      ),
    );
  }
}

