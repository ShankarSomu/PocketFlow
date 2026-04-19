import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class BalanceCard extends StatefulWidget {

  const BalanceCard({
    required this.totalBalance, required this.cashAvailable, required this.monthlyChange, required this.fmt, super.key,
  });
  final double totalBalance;
  final double cashAvailable;
  final double monthlyChange;
  final NumberFormat fmt;

  @override
  State<BalanceCard> createState() => BalanceCardState();
}

class BalanceCardState extends State<BalanceCard> {
  bool _showBalance = true;

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.monthlyChange >= 0;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Balance', style: TextStyle(color: AppTheme.slate500, fontSize: 12)),
              IconButton(
                icon: Icon(_showBalance ? Icons.visibility : Icons.visibility_off, color: AppTheme.slate400, size: 22),
                onPressed: () => setState(() => _showBalance = !_showBalance),
                tooltip: _showBalance ? 'Hide balance' : 'Show balance',
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showBalance
                ? Text(widget.fmt.format(widget.totalBalance),
                    key: const ValueKey('balance'),
                    style: const TextStyle(fontSize: 36, color: AppTheme.slate900, fontWeight: FontWeight.w300))
                : Container(
                    key: const ValueKey('hidden'),
                    height: 40,
                    alignment: Alignment.centerLeft,
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: 8,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (_, __) => Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.slate200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Mini chart placeholder
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('Mini Chart', style: TextStyle(color: AppTheme.slate400, fontSize: 14)),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cash Available', style: TextStyle(color: AppTheme.slate500, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(widget.fmt.format(widget.cashAvailable), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPositive ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                        color: isPositive ? AppTheme.emerald : AppTheme.error, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${isPositive ? '+' : '-'}${widget.fmt.format(widget.monthlyChange.abs())}',
                      style: TextStyle(
                        color: isPositive ? AppTheme.emerald : AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
