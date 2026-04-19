import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../models/transaction.dart' as model;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  /// Initialize the notification system
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap - could navigate to specific screens
      },
    );

    _initialized = true;
  }

  /// Get notification preferences from SharedPreferences
  static Future<Map<String, bool>> _getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'transactions': prefs.getBool('notif_transactions') ?? true,
      'budget': prefs.getBool('notif_budget') ?? true,
      'weekly': prefs.getBool('notif_weekly') ?? true,
    };
  }

  /// Show notification for a new transaction
  static Future<void> notifyTransaction(model.Transaction transaction) async {
    await initialize();
    
    final prefs = await _getPreferences();
    if (prefs['transactions'] != true) return;

    const androidDetails = AndroidNotificationDetails(
      'transactions',
      'Transaction Alerts',
      channelDescription: 'Notifications for added transactions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    final isExpense = transaction.type == 'expense';
    final icon = isExpense ? '💸' : '💰';
    final action = isExpense ? 'spent' : 'received';
    final amount = NumberFormat.currency(symbol: '\$').format(transaction.amount);

    await _notifications.show(
      transaction.id ?? 0,
      '$icon Transaction $action',
      '$amount on ${transaction.category}${transaction.note?.isNotEmpty ?? false ? " • ${transaction.note}" : ""}',
      details,
    );
  }

  /// Check budget and show warning if threshold exceeded
  static Future<void> checkBudgetWarnings(String category, DateTime date) async {
    await initialize();
    
    final prefs = await _getPreferences();
    if (prefs['budget'] != true) return;

    final month = date.month;
    final year = date.year;

    // Get budget for this category
    final budgets = await AppDatabase.getBudgets(month, year);
    final budget = budgets.where((b) => b.category == category).firstOrNull;
    
    if (budget == null) return;

    // Calculate spending for this category this month
    final startDate = DateTime(year, month);
    final endDate = DateTime(year, month + 1, 0);
    
    final transactions = await AppDatabase.getTransactions(
      type: 'expense',
      from: startDate,
      to: endDate,
    );
    
    final spending = transactions
        .where((t) => t.category == category)
        .fold(0.0, (sum, t) => sum + t.amount);

    final percentage = (spending / budget.limit) * 100;

    // Only notify at 80% and 90% thresholds
    const androidDetails = AndroidNotificationDetails(
      'budget_warnings',
      'Budget Warnings',
      channelDescription: 'Alerts when nearing budget limits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    if (percentage >= 90 && percentage < 100) {
      await _notifications.show(
        category.hashCode + 90,
        '⚠️ Budget Alert: $category',
        'You\'ve used ${percentage.toStringAsFixed(0)}% of your ${NumberFormat.currency(symbol: '\$').format(budget.limit)} budget',
        details,
      );
    } else if (percentage >= 80 && percentage < 90) {
      await _notifications.show(
        category.hashCode + 80,
        '⚠️ Budget Warning: $category',
        'You\'ve used ${percentage.toStringAsFixed(0)}% of your ${NumberFormat.currency(symbol: '\$').format(budget.limit)} budget',
        details,
      );
    } else if (percentage >= 100) {
      await _notifications.show(
        category.hashCode + 100,
        '🚨 Budget Exceeded: $category',
        'You\'ve exceeded your ${NumberFormat.currency(symbol: '\$').format(budget.limit)} budget by ${NumberFormat.currency(symbol: '\$').format(spending - budget.limit)}',
        details,
      );
    }
  }

  /// Schedule weekly summary notification
  static Future<void> scheduleWeeklySummary() async {
    await initialize();
    
    final prefs = await _getPreferences();
    if (prefs['weekly'] != true) {
      // Cancel if preference is disabled
      await _notifications.cancel(999);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'weekly_summary',
      'Weekly Summary',
      channelDescription: 'Weekly spending summary',
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    // Get last week's data for the notification content
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final transactions = await AppDatabase.getTransactions(
      from: weekAgo,
      to: now,
    );

    final expenses = transactions.where((t) => t.type == 'expense');
    final income = transactions.where((t) => t.type == 'income');
    
    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = income.fold(0.0, (sum, t) => sum + t.amount);
    
    final expenseStr = NumberFormat.currency(symbol: '\$').format(totalExpense);
    final incomeStr = NumberFormat.currency(symbol: '\$').format(totalIncome);

    // Schedule weekly notification
    // Note: This shows a summary based on current data, repeating weekly
    await _notifications.periodicallyShow(
      999, // Fixed ID for weekly summary
      '📊 Your Weekly Summary',
      'Last 7 days: Spent $expenseStr • Earned $incomeStr • ${transactions.length} transactions',
      RepeatInterval.weekly,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Request notification permissions (Android 13+)
  static Future<bool> requestPermissions() async {
    await initialize();
    
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    return result ?? true;
  }
}
