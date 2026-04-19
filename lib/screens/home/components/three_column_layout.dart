import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;
import 'accounts_quick_view.dart';
import 'recent_transactions_quick.dart';

class ThreeColumnLayout extends StatelessWidget {

  const ThreeColumnLayout({
    required this.accountsQuickView, required this.recent, required this.fmt, super.key,
  });
  final List<Map<String, dynamic>> accountsQuickView;
  final List<model.Transaction> recent;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          AccountsQuickView(accounts: accountsQuickView, fmt: fmt),
          const SizedBox(height: 16),
          RecentTransactionsQuick(recent: recent, fmt: fmt),
        ],
      ),
    );
  }
}
