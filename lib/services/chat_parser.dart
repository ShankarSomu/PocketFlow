import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart' as model;
import 'app_logger.dart';
import 'refresh_notifier.dart';

sealed class ParseResult {}

class ParseSuccess extends ParseResult {
  ParseSuccess(this.message);
  final String message;
}

class ParseError extends ParseResult {
  ParseError(this.message);
  final String message;
}

class ChatParser {
  static const _prefDefaultExpenseAccount = 'default_expense_account';
  static const _prefDefaultIncomeAccount = 'default_income_account';

  // ── Default account management ──────────────────────────────────────────────

  static Future<int?> getDefaultExpenseAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefDefaultExpenseAccount);
  }

  static Future<int?> getDefaultIncomeAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefDefaultIncomeAccount);
  }

  static Future<void> setDefaultExpenseAccount(int? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await prefs.remove(_prefDefaultExpenseAccount);
    } else {
      await prefs.setInt(_prefDefaultExpenseAccount, accountId);
    }
  }

  static Future<void> setDefaultIncomeAccount(int? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await prefs.remove(_prefDefaultIncomeAccount);
    } else {
      await prefs.setInt(_prefDefaultIncomeAccount, accountId);
    }
  }

  // Supported formats:
  //   expense <amount> <category>[/<subcategory>] [note] [@account]
  //   income <amount> <category>[/<subcategory>] [note] [@account]
  //   budget <category> <amount>
  //   savings <name> <target>
  //   contribute <name> <amount>
  //   account <name> <type> [opening_balance]
  //   transfer <from_account> <to_account> <amount> [note]

  static Future<ParseResult> parse(String input) async {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return ParseError('Empty input');
    final cmd = parts[0].toLowerCase();

    // Handle yes/no responses for pending actions
    if (cmd == 'yes' || cmd == 'y') {
      return ParseSuccess('Please use the confirmation buttons in the chat.');
    }
    if (cmd == 'no' || cmd == 'n') {
      return ParseSuccess('Okay, cancelled.');
    }

    try {
      switch (cmd) {
        case 'expense':
        case 'income':
          if (parts.length < 3) {
            return ParseError(
                'Usage: $cmd <amount> <category>[/<subcategory>] [note] [@account]');
          }
          final amount = double.tryParse(parts[1]);
          if (amount == null || amount <= 0) return ParseError('Invalid amount');

          // Support category/subcategory syntax
          final rawCat = parts[2].toLowerCase();
          final category = rawCat.contains('/')
              ? rawCat.split('/').last
              : rawCat;

          int? accountId;
          String? accountName;
          final remaining = parts.sublist(3).toList();
          final atIdx = remaining.indexWhere((p) => p.startsWith('@'));
          if (atIdx != -1) {
            final tag = remaining[atIdx].substring(1).toLowerCase();
            remaining.removeAt(atIdx);
            final accounts = await AppDatabase.getAccounts();
            final match = accounts
                .where((a) => a.name.toLowerCase().contains(tag))
                .firstOrNull;
            if (match != null) {
              accountId = match.id;
              accountName = match.name;
            }
          } else {
            // Use default account if no @account specified
            final defaultId = cmd == 'expense'
                ? await getDefaultExpenseAccount()
                : await getDefaultIncomeAccount();
            if (defaultId != null) {
              final accounts = await AppDatabase.getAccounts();
              final match = accounts.where((a) => a.id == defaultId).firstOrNull;
              if (match != null) {
                accountId = match.id;
                accountName = match.name;
              }
            }
          }
          final note = remaining.isEmpty ? null : remaining.join(' ');

          await AppDatabase.insertTransaction(model.Transaction(
            type: cmd,
            amount: amount,
            category: category,
            note: note,
            date: DateTime.now(),
            accountId: accountId,
          ));
          notifyDataChanged();
          final acctSuffix = accountName != null ? ' → $accountName' : '';
          final msg = '✓ $cmd \$${amount.toStringAsFixed(2)} — $category$acctSuffix';
          AppLogger.userAction('chat:$cmd', detail: '\$${amount.toStringAsFixed(2)} $category$acctSuffix');
          return ParseSuccess(msg);

        case 'budget':
          if (parts.length < 3) {
            return ParseError('Usage: budget <category> <amount>');
          }
          final category = parts[1].toLowerCase();
          final limit = double.tryParse(parts[2]);
          if (limit == null || limit < 0) return ParseError('Invalid amount');
          final now = DateTime.now();
          await AppDatabase.upsertBudget(Budget(
            category: category,
            limit: limit,
            month: now.month,
            year: now.year,
          ));
          notifyDataChanged();
          return ParseSuccess(
              '✓ Budget set: $category = \$${limit.toStringAsFixed(2)}');

        case 'savings':
          if (parts.length < 3) {
            return ParseError('Usage: savings <name> <target>');
          }
          final name = parts[1].toLowerCase();
          final target = double.tryParse(parts[2]);
          if (target == null || target <= 0) return ParseError('Invalid target');
          await AppDatabase.insertGoal(
              SavingsGoal(name: name, target: target, saved: 0));
          notifyDataChanged();
          return ParseSuccess(
              '✓ Goal created: $name = \$${target.toStringAsFixed(2)}');

        case 'contribute':
          if (parts.length < 3) {
            return ParseError('Usage: contribute <name> <amount>');
          }
          final name = parts[1].toLowerCase();
          final amount = double.tryParse(parts[2]);
          if (amount == null || amount <= 0) return ParseError('Invalid amount');
          final goals = await AppDatabase.getGoals();
          final goal = goals.where((g) => g.name == name).firstOrNull;
          if (goal == null) return ParseError('Goal "$name" not found');
          await AppDatabase.updateGoalSaved(goal.id!, goal.saved + amount);
          notifyDataChanged();
          return ParseSuccess(
              '✓ Added \$${amount.toStringAsFixed(2)} to $name');

        case 'account':
          if (parts.length < 3) {
            return ParseError(
                'Usage: account <name> <type> [balance]\nTypes: ${Account.types.join(', ')}');
          }
          final name = parts[1];
          final type = parts[2].toLowerCase();
          if (!Account.types.contains(type)) {
            return ParseError('Invalid type. Use: ${Account.types.join(', ')}');
          }
          final balance =
              parts.length > 3 ? (double.tryParse(parts[3]) ?? 0) : 0.0;
          await AppDatabase.insertAccount(
              Account(name: name, type: type, balance: balance));
          notifyDataChanged();
          return ParseSuccess('✓ Account created: $name ($type)');

        case 'category':
          // category <name> [icon]
          if (parts.length < 2) {
            return ParseError('Usage: category <name> [emoji]');
          }
          final catName = parts.sublist(1).where((p) => !p.startsWith('icon:')).join(' ');
          final iconPart = parts.firstWhere((p) => p.startsWith('icon:'), orElse: () => '');
          final icon = iconPart.isNotEmpty ? iconPart.substring(5) : '📁';
          await AppDatabase.insertCategory(Category(
            name: catName,
            icon: icon,
          ));
          notifyDataChanged();
          return ParseSuccess('✓ Category created: $icon $catName');

        case 'subcategory':
          // subcategory <parent> <name>
          if (parts.length < 3) {
            return ParseError('Usage: subcategory <parent_category> <name>');
          }
          final parentName = parts[1];
          final subName = parts.sublist(2).join(' ');
          final allCats = await AppDatabase.getTopLevelCategories();
          final parent = allCats
              .where((c) => c.name.toLowerCase() == parentName.toLowerCase())
              .firstOrNull;
          if (parent == null) {
            return ParseError('Category "$parentName" not found.\nAvailable: ${allCats.map((c) => c.name).join(', ')}');
          }
          await AppDatabase.insertCategory(Category(
            name: subName,
            parentId: parent.id,
            icon: parent.icon,
            color: parent.color,
          ));
          notifyDataChanged();
          return ParseSuccess('✓ Subcategory "$subName" added to ${parent.icon} ${parent.name}');

        case 'transfer':
          if (parts.length < 4) {
            return ParseError(
                'Usage: transfer <from_account> <to_account> <amount> [note]');
          }
          final fromName = parts[1].toLowerCase();
          final toName = parts[2].toLowerCase();
          final amount = double.tryParse(parts[3]);
          if (amount == null || amount <= 0) return ParseError('Invalid amount');
          final note = parts.length > 4 ? parts.sublist(4).join(' ') : null;

          final accounts = await AppDatabase.getAccounts();
          final from = accounts
              .where((a) => a.name.toLowerCase().contains(fromName))
              .firstOrNull;
          final to = accounts
              .where((a) => a.name.toLowerCase().contains(toName))
              .firstOrNull;
          if (from == null) return ParseError('Account "$fromName" not found');
          if (to == null) return ParseError('Account "$toName" not found');
          if (from.id == to.id) {
            return ParseError('From and To must be different accounts');
          }

          await AppDatabase.transfer(
            fromId: from.id!,
            toId: to.id!,
            amount: amount,
            note: note,
          );
          notifyDataChanged();
          AppLogger.userAction('chat:transfer', detail: '\$${amount.toStringAsFixed(2)} ${from.name} → ${to.name}');
          return ParseSuccess(
              '✓ Transferred \$${amount.toStringAsFixed(2)} from ${from.name} → ${to.name}');

        default:
          return ParseError(
              'Unknown command.\nTry: expense, income, budget, savings, contribute, account, transfer, category, subcategory\n\nTips:\n  expense 45 food/groceries\n  category Fitness 🏋\n  subcategory Food Sushi');
      }
    } catch (e) {
      AppLogger.err('chat:$cmd failed', e, category: LogCategory.userAction);
      return ParseError('Error: $e');
    }
  }
}
