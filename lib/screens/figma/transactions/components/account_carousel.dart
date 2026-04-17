import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/account.dart';
import '../../../../services/theme_service.dart';
import 'transaction_helpers.dart';

/// Account carousel for transactions screen with swipeable account cards
class TransactionAccountCarousel extends StatelessWidget {
  final List<Account> accounts;
  final Map<int, double> balances;
  final int carouselIdx; // 0 = All, 1..N = individual
  final ValueChanged<int> onIndexChanged;
  final NumberFormat fmt;

  const TransactionAccountCarousel({
    super.key,
    required this.accounts,
    required this.balances,
    required this.carouselIdx,
    required this.onIndexChanged,
    required this.fmt,
  });

  int get _total => accounts.length + 1; // +1 for "All" card

  void _prev() => onIndexChanged((carouselIdx - 1 + _total) % _total);
  void _next() => onIndexChanged((carouselIdx + 1) % _total);

  @override
  Widget build(BuildContext context) {
    // Compute "All" total balance
    double totalBalance = 0;
    for (final a in accounts) {
      final bal = balances[a.id] ?? 0;
      totalBalance += a.type == 'credit' ? -bal : bal;
    }

    Widget cardContent;
    List<Color> gradColors;

    if (carouselIdx == 0) {
      // All accounts card
      gradColors = [
        Theme.of(context).colorScheme.inverseSurface,
        Theme.of(context).colorScheme.inverseSurface.withOpacity(0.85)
      ];
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
                      .withOpacity(0.15),
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
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${accounts.length} accounts',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.7),
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Net Balance',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withOpacity(0.7),
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
    } else {
      final account = accounts[carouselIdx - 1];
      final balance = balances[account.id] ?? 0;
      gradColors = accountGradient(context, account.type);
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
                      .withOpacity(0.15),
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
                              .withOpacity(0.7),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            account.type == 'credit' ? 'Outstanding' : 'Balance',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withOpacity(0.7),
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
            gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: ThemeService.instance.primaryShadow,
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
                                .withOpacity(0.38),
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
  final IconData icon;
  final VoidCallback onTap;

  const CarouselArrow({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
            size: 28),
      ),
    );
  }
}
