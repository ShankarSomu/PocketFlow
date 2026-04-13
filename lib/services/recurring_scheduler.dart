import '../db/database.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as model;
import 'refresh_notifier.dart';
import 'app_logger.dart';

class RecurringScheduler {
  static Future<int> processDue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recurring = await AppDatabase.getRecurring();
    int count = 0;

    for (final r in recurring) {
      if (!r.isActive) continue;
      var due = DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
      if (due.isAfter(today)) continue;

      while (!due.isAfter(today)) {
        await _execute(r, due);
        due = r.nextAfter(due);
        count++;
        // 'once' — mark inactive after first execution
        if (r.frequency == 'once') {
          await AppDatabase.updateRecurring(_copyWith(r, isActive: false, nextDueDate: due));
          break;
        }
      }

      if (r.frequency != 'once') {
        await AppDatabase.updateRecurring(_copyWith(r, nextDueDate: due));
      }
    }

    if (count > 0) notifyDataChanged();
    AppLogger.scheduler('processDue completed', detail: '$count transactions created');
    return count;
  }

  static Future<void> _execute(RecurringTransaction r, DateTime date) async {
    AppLogger.scheduler('execute recurring', detail: '${r.type} \$${r.amount} ${r.category} on ${date.toIso8601String().substring(0,10)}');
    if (r.type == 'transfer') {
      // Transfer between accounts
      if (r.accountId != null && r.toAccountId != null) {
        await AppDatabase.transfer(
          fromId: r.accountId!,
          toId: r.toAccountId!,
          amount: r.amount,
          note: 'recurring:${r.id}',
          date: date,
        );
      }
    } else if (r.type == 'goal') {
      // Contribute to savings goal
      if (r.goalId != null) {
        final goals = await AppDatabase.getGoals();
        final goal = goals.where((g) => g.id == r.goalId).firstOrNull;
        if (goal != null) {
          await AppDatabase.updateGoalSaved(goal.id!, goal.saved + r.amount);
          // Also record as expense from source account if linked
          if (r.accountId != null) {
            await AppDatabase.insertTransaction(model.Transaction(
              type: 'expense',
              amount: r.amount,
              category: 'savings',
              note: 'Goal: ${goal.name}',
              date: date,
              accountId: r.accountId,
              recurringId: r.id,
            ));
          }
        }
      }
    } else {
      // Regular income/expense
      await AppDatabase.insertTransaction(model.Transaction(
        type: r.type,
        amount: r.amount,
        category: r.category,
        note: r.note,
        date: date,
        accountId: r.accountId,
        recurringId: r.id,
      ));
    }
  }

  static Future<void> onUpdated(RecurringTransaction updated) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String();
    final d = await AppDatabase.db;

    // Delete future transactions for this recurring entry
    if (updated.type == 'transfer') {
      final tag = 'recurring:${updated.id}';
      await d.delete(
        'transactions',
        where: 'note = ? AND date >= ?',
        whereArgs: [tag, todayStr],
      );
    } else {
      await d.delete(
        'transactions',
        where: 'recurring_id = ? AND date >= ?',
        whereArgs: [updated.id, todayStr],
      );
    }

    // Respect the user's chosen due date exactly — do NOT reset to today
    // Only save the updated recurring entry with the new due date as-is
    await AppDatabase.updateRecurring(updated);

    // Only process if due date is today or past
    final due = DateTime(
        updated.nextDueDate.year,
        updated.nextDueDate.month,
        updated.nextDueDate.day);
    if (!due.isAfter(today)) {
      await _processOne(updated.id!);
    }
    // If future date — just save it, scheduler will pick it up when due
    notifyDataChanged();
  }

  static Future<void> _processOne(int recurringId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = await AppDatabase.getRecurring();
    final r = all.where((r) => r.id == recurringId).firstOrNull;
    if (r == null || !r.isActive) return;

    var due = DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
    // Nothing to process if due is in the future
    if (due.isAfter(today)) return;

    while (!due.isAfter(today)) {
      await _execute(r, due);
      due = r.nextAfter(due);
      if (r.frequency == 'once') {
        await AppDatabase.updateRecurring(_copyWith(r, isActive: false, nextDueDate: due));
        return;
      }
    }
    // Save next future due date
    await AppDatabase.updateRecurring(_copyWith(r, nextDueDate: due));
    notifyDataChanged();
  }

  static RecurringTransaction _copyWith(
    RecurringTransaction r, {
    DateTime? nextDueDate,
    bool? isActive,
  }) =>
      RecurringTransaction(
        id: r.id,
        type: r.type,
        amount: r.amount,
        category: r.category,
        note: r.note,
        accountId: r.accountId,
        toAccountId: r.toAccountId,
        goalId: r.goalId,
        frequency: r.frequency,
        nextDueDate: nextDueDate ?? r.nextDueDate,
        isActive: isActive ?? r.isActive,
      );
}



