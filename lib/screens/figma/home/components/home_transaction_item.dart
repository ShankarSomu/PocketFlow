import 'package:flutter/material.dart';

/// Helper class for transaction icons and colors
class HomeTransactionItem {
  static IconData icon(String category, bool isIncome) {
    if (isIncome) return Icons.arrow_downward_rounded;
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('lunch') || c.contains('dinner') || c.contains('restaurant') || c.contains('grocery') || c.contains('groceries')) return Icons.restaurant_rounded;
    if (c.contains('transport') || c.contains('uber') || c.contains('gas') || c.contains('car') || c.contains('fuel')) return Icons.directions_car_rounded;
    if (c.contains('shopping') || c.contains('amazon') || c.contains('retail') || c.contains('clothes')) return Icons.shopping_bag_rounded;
    if (c.contains('netflix') || c.contains('spotify') || c.contains('subscription') || c.contains('streaming')) return Icons.subscriptions_rounded;
    if (c.contains('health') || c.contains('medical') || c.contains('doctor') || c.contains('pharmacy')) return Icons.local_hospital_rounded;
    if (c.contains('home') || c.contains('rent') || c.contains('mortgage') || c.contains('electric') || c.contains('utility')) return Icons.home_rounded;
    if (c.contains('gym') || c.contains('fitness') || c.contains('sport')) return Icons.fitness_center_rounded;
    if (c.contains('travel') || c.contains('flight') || c.contains('hotel') || c.contains('vacation')) return Icons.flight_rounded;
    if (c.contains('coffee') || c.contains('cafe') || c.contains('tea')) return Icons.coffee_rounded;
    if (c.contains('education') || c.contains('school') || c.contains('book') || c.contains('tuition')) return Icons.school_rounded;
    if (c.contains('salary') || c.contains('payroll') || c.contains('wage')) return Icons.account_balance_wallet_rounded;
    if (c.contains('insurance')) return Icons.shield_rounded;
    if (c.contains('phone') || c.contains('mobile') || c.contains('internet')) return Icons.phone_android_rounded;
    return Icons.receipt_rounded;
  }

  static Color color(BuildContext context, String category, bool isIncome) {
    if (isIncome) return Theme.of(context).colorScheme.tertiary;
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('lunch')) return Theme.of(context).colorScheme.tertiaryContainer;
    if (c.contains('transport') || c.contains('car') || c.contains('uber')) return Theme.of(context).colorScheme.primary;
    if (c.contains('shopping') || c.contains('amazon')) return Theme.of(context).colorScheme.secondary;
    if (c.contains('netflix') || c.contains('streaming') || c.contains('subscription')) return Theme.of(context).colorScheme.error;
    if (c.contains('health') || c.contains('medical')) return Theme.of(context).colorScheme.inversePrimary;
    if (c.contains('home') || c.contains('rent')) return Theme.of(context).colorScheme.secondary;
    if (c.contains('gym') || c.contains('fitness')) return Theme.of(context).colorScheme.tertiary;
    if (c.contains('travel') || c.contains('flight')) return Theme.of(context).colorScheme.inversePrimary;
    if (c.contains('coffee') || c.contains('cafe')) return Theme.of(context).colorScheme.tertiary;
    if (c.contains('education') || c.contains('school')) return Theme.of(context).colorScheme.secondary;
    return Theme.of(context).colorScheme.primary;
  }
}
