import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/account.dart';
import '../../../../services/theme_service.dart';
import '../../../../theme/app_theme.dart';
import '../../intelligence/intelligence_screens.dart';
import 'transaction_helpers.dart';

/// Account carousel for transactions screen with swipeable account cards
class TransactionAccountCarousel extends StatelessWidget {

  const TransactionAccountCarousel({
    required this.accounts,
    required this.balances,
    required this.carouselIdx,
    required this.onIndexChanged,
    required this.fmt,
    this.hasIntelligence = false,
    this.pendingActionsCount = 0,
    this.transfersCount = 0,
    this.patternsCount = 0,
    super.key,
  });
  final List<Account> accounts;
  final Map<int, double> balances;
  final int carouselIdx; // 0 = All, 1..N = individual accounts, last = intelligence (if hasIntelligence)
  final ValueChanged<int> onIndexChanged;
  final NumberFormat fmt;
  final bool hasIntelligence;
  final int pendingActionsCount;
  final int transfersCount;
  final int patternsCount;

  int get _total => accounts.length + 1 + (hasIntelligence ? 1 : 0); // +1 for "All" card, +1 for intelligence if present

  void _prev() => onIndexChanged((carouselIdx - 1 + _total) % _total);
  void _next() => onIndexChanged((carouselIdx + 1) % _total);

  @override
  Widget build(BuildContext context) {
    // Compute "All" total balance
    double totalBalance = 0;
    for (final a in accounts) {
      final bal = balances[a.id] ?? 0;
      totalBalance += a.isLiability ? -bal : bal;
    }

    Widget cardContent;
    final int intelligenceIdx = accounts.length + 1; // Intelligence card is after all account cards

    if (carouselIdx == 0) {
      // All accounts card
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: Theme.of(context).colorScheme.onPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('All Accounts',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${accounts.length} accounts',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7),
                        fontSize: 11)),
              ),
              if (hasIntelligence) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'View Intelligence',
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to intelligence card in carousel
                      onIndexChanged(accounts.length + 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (pendingActionsCount + transfersCount + patternsCount) > 0
                            ? Colors.orange.shade100
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_graph_rounded,
                        color: (pendingActionsCount + transfersCount + patternsCount) > 0
                            ? Colors.orange.shade700
                            : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('Net Balance',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.7),
                  fontSize: 12)),
          const SizedBox(height: 4),
          Text(fmt.format(totalBalance),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5)),
        ],
      );
    } else if (hasIntelligence && carouselIdx == intelligenceIdx) {
      // Intelligence card
      final totalItems = pendingActionsCount + transfersCount + patternsCount;
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_graph_rounded,
                    color: Theme.of(context).colorScheme.onPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Intelligence',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(
                      'SMS Pattern Detection',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalItems > 0 
                      ? Colors.orange.shade100
                      : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalItems > 0 ? '$totalItems items' : 'No items',
                  style: TextStyle(
                      color: totalItems > 0 
                          ? Colors.orange.shade700
                          : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IntelligenceStatItem(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  count: pendingActionsCount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntelligenceStatItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfers',
                  count: transfersCount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntelligenceStatItem(
                  icon: Icons.repeat_rounded,
                  label: 'Patterns',
                  count: patternsCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SmsIntelligenceDashboardScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      final account = accounts[carouselIdx - 1];
      final balance = balances[account.id] ?? 0;
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(accountIcon(account.type),
                    color: Theme.of(context).colorScheme.onPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      account.type[0].toUpperCase() +
                          account.type.substring(1) +
                          (account.last4 != null
                              ? '  ····${account.last4}'
                              : ''),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            account.isLiability ? 'Outstanding' : 'Balance',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.7),
                fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(fmt.format(balance),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5)),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.fromLTRB(44, 16, 44, 16),
          decoration: BoxDecoration(
            gradient: ThemeService.instance.cardGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: cardContent,
        ),
        // Page dots
        Positioned(
          bottom: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                _total,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == carouselIdx ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == carouselIdx
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
          ),
        ),
        // Left arrow (circular)
        Positioned(
          left: 0,
          child: CarouselArrow(icon: Icons.chevron_left_rounded, onTap: _prev),
        ),
        // Right arrow (circular)
        Positioned(
          right: 0,
          child:
              CarouselArrow(icon: Icons.chevron_right_rounded, onTap: _next),
        ),
      ],
    );
  }
}

class CarouselArrow extends StatelessWidget {

  const CarouselArrow({
    required this.icon, required this.onTap, super.key,
  });
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
            size: 28),
      ),
    );
  }
}

class _IntelligenceStatItem extends StatelessWidget {
  const _IntelligenceStatItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
            size: 18,
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

