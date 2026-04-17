import 'package:flutter/material.dart';

/// Helper functions for transaction UI components

/// Returns gradient colors for account type
List<Color> accountGradient(BuildContext context, String type) => switch (type) {
      'checking' || 'debit' => [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withOpacity(0.8)
        ],
      'savings' => [
          Theme.of(context).colorScheme.tertiary,
          Theme.of(context).colorScheme.tertiary.withOpacity(0.8)
        ],
      'credit' => [
          Theme.of(context).colorScheme.error,
          Theme.of(context).colorScheme.error.withOpacity(0.8)
        ],
      'cash' => [
          Theme.of(context).colorScheme.secondary,
          Theme.of(context).colorScheme.secondary.withOpacity(0.8)
        ],
      'investment' => [
          Theme.of(context).colorScheme.inversePrimary,
          Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8)
        ],
      _ => [
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8)
        ],
    };

/// Returns icon for account type
IconData accountIcon(String type) => switch (type) {
      'checking' || 'debit' => Icons.account_balance_rounded,
      'savings' => Icons.savings_rounded,
      'credit' => Icons.credit_card_rounded,
      'cash' => Icons.payments_rounded,
      'investment' => Icons.trending_up_rounded,
      _ => Icons.account_balance_wallet_rounded,
    };

/// Returns color for transaction category
Color colorForCategory(BuildContext context, String category) {
  if (category.contains('food') ||
      category.contains('lunch') ||
      category.contains('dinner') ||
      category.contains('restaurant') ||
      category.contains('grocery') ||
      category.contains('groceries')) {
    return Theme.of(context).colorScheme.tertiaryContainer;
  }
  if (category.contains('transport') ||
      category.contains('uber') ||
      category.contains('gas') ||
      category.contains('car') ||
      category.contains('fuel')) {
    return Theme.of(context).colorScheme.primary;
  }
  if (category.contains('shopping') ||
      category.contains('amazon') ||
      category.contains('retail') ||
      category.contains('clothes')) {
    return Theme.of(context).colorScheme.secondary;
  }
  if (category.contains('netflix') ||
      category.contains('spotify') ||
      category.contains('subscription') ||
      category.contains('streaming')) {
    return Theme.of(context).colorScheme.error;
  }
  if (category.contains('health') ||
      category.contains('medical') ||
      category.contains('doctor') ||
      category.contains('pharmacy')) {
    return Theme.of(context).colorScheme.primaryContainer;
  }
  if (category.contains('home') ||
      category.contains('rent') ||
      category.contains('mortgage') ||
      category.contains('electric') ||
      category.contains('utility')) {
    return Theme.of(context).colorScheme.secondary;
  }
  if (category.contains('gym') ||
      category.contains('fitness') ||
      category.contains('sport')) {
    return Theme.of(context).colorScheme.tertiary;
  }
  if (category.contains('travel') ||
      category.contains('flight') ||
      category.contains('hotel') ||
      category.contains('vacation')) {
    return Theme.of(context).colorScheme.inversePrimary;
  }
  if (category.contains('coffee') ||
      category.contains('cafe') ||
      category.contains('tea')) {
    return Theme.of(context).colorScheme.tertiary;
  }
  if (category.contains('education') ||
      category.contains('school') ||
      category.contains('book') ||
      category.contains('tuition')) {
    return Theme.of(context).colorScheme.secondaryContainer;
  }
  return Theme.of(context).colorScheme.primary;
}

/// Returns icon for transaction category
IconData iconForCategory(String category) {
  if (category.contains('food') ||
      category.contains('lunch') ||
      category.contains('dinner') ||
      category.contains('restaurant') ||
      category.contains('grocery') ||
      category.contains('groceries')) {
    return Icons.restaurant_rounded;
  }
  if (category.contains('transport') ||
      category.contains('uber') ||
      category.contains('gas') ||
      category.contains('car') ||
      category.contains('fuel')) {
    return Icons.directions_car_rounded;
  }
  if (category.contains('shopping') ||
      category.contains('amazon') ||
      category.contains('retail') ||
      category.contains('clothes')) {
    return Icons.shopping_bag_rounded;
  }
  if (category.contains('netflix') ||
      category.contains('spotify') ||
      category.contains('subscription') ||
      category.contains('streaming')) {
    return Icons.subscriptions_rounded;
  }
  if (category.contains('health') ||
      category.contains('medical') ||
      category.contains('doctor') ||
      category.contains('pharmacy')) {
    return Icons.local_hospital_rounded;
  }
  if (category.contains('home') ||
      category.contains('rent') ||
      category.contains('mortgage') ||
      category.contains('electric') ||
      category.contains('utility')) {
    return Icons.home_rounded;
  }
  if (category.contains('gym') ||
      category.contains('fitness') ||
      category.contains('sport')) {
    return Icons.fitness_center_rounded;
  }
  if (category.contains('travel') ||
      category.contains('flight') ||
      category.contains('hotel') ||
      category.contains('vacation')) {
    return Icons.flight_rounded;
  }
  if (category.contains('coffee') ||
      category.contains('cafe') ||
      category.contains('tea')) {
    return Icons.coffee_rounded;
  }
  if (category.contains('education') ||
      category.contains('school') ||
      category.contains('book') ||
      category.contains('tuition')) {
    return Icons.school_rounded;
  }
  if (category.contains('salary') ||
      category.contains('payroll') ||
      category.contains('wage')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (category.contains('insurance')) {
    return Icons.shield_rounded;
  }
  if (category.contains('phone') ||
      category.contains('mobile') ||
      category.contains('internet')) {
    return Icons.phone_android_rounded;
  }
  return Icons.receipt_rounded;
}
