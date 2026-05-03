import '../db/database.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as model;
import 'app_logger.dart';
import 'refresh_notifier.dart';

class UnifiedRuleEngine {
  static const String recurringRuleType = 'recurring';
  static const String loanRuleType = 'loan';

  /// Execute all registered rules in an inclusive date range.
  static Future<int> processRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final from = _atDayStart(fromDate);
    final to = _atDayStart(toDate);
    if (to.isBefore(from)) return 0;

    int created = 0;
    created += await _processRecurringRules(from: from, to: to);
    // Loan rules are introduced in phase 2; this keeps a single engine entrypoint.
    created += await _processLoanRules(from: from, to: to);

    if (created > 0) {
      notifyDataChanged();
    }
    AppLogger.scheduler(
      'rule_engine.processRange completed',
      detail: '$created transactions ($from -> $to)',
    );
    return created;
  }

  /// Simulates rules for a date range without writing DB state.
  static Future<List<model.Transaction>> simulateTime({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final from = _atDayStart(fromDate);
    final to = _atDayStart(toDate);
    if (to.isBefore(from)) return [];

    final projections = <model.Transaction>[];
    final recurring = await AppDatabase.getRecurring();
    for (final rule in recurring) {
      if (!rule.isActive || rule.id == null) continue;
      var due = _atDayStart(rule.nextDueDate);
      while (!due.isAfter(to)) {
        if (!due.isBefore(from) && !due.isAfter(to)) {
          projections.add(
            model.Transaction(
              type: rule.type,
              amount: rule.amount,
              category: rule.category,
              note: rule.note,
              date: due,
              accountId: rule.accountId ?? 0,
              recurringId: rule.id,
              sourceType: 'recurring',
              ruleType: recurringRuleType,
              referenceRuleId: rule.id,
            ),
          );
        }
        if (rule.frequency == 'once') break;
        due = _atDayStart(rule.nextAfter(due));
      }
    }
    return projections;
  }

  static Future<void> processToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await processRange(fromDate: today, toDate: today);
  }

  static Future<void> onRecurringRuleUpdated(
    RecurringTransaction updated, {
    bool rewritePastTransactions = true,
    DateTime? effectiveFromDate,
  }) async {
    final d = await AppDatabase.db();

    if (updated.id == null) {
      await AppDatabase.updateRecurring(updated);
      return;
    }

    final today = _atDayStart(DateTime.now());
    final effectiveFrom = rewritePastTransactions
        ? _atDayStart(updated.startDate ?? updated.nextDueDate)
        : _atDayStart(
            effectiveFromDate ?? DateTime(today.year, today.month, 1),
          );

    if (rewritePastTransactions) {
      await d.delete(
        'execution_logs',
        where: 'rule_type = ? AND rule_id = ?',
        whereArgs: [recurringRuleType, updated.id],
      );
      await d.delete(
        'transactions',
        where: 'recurring_id = ?',
        whereArgs: [updated.id],
      );
    } else {
      await d.delete(
        'execution_logs',
        where: 'rule_type = ? AND rule_id = ? AND execution_date >= ?',
        whereArgs: [
          recurringRuleType,
          updated.id,
          _executionDateKey(effectiveFrom),
        ],
      );
      await d.delete(
        'transactions',
        where: 'recurring_id = ? AND date >= ?',
        whereArgs: [updated.id, effectiveFrom.toIso8601String()],
      );
    }

    final nextDue = rewritePastTransactions
        ? _atDayStart(updated.startDate ?? updated.nextDueDate)
        : _firstDueOnOrAfter(updated, effectiveFrom);

    final reset = RecurringTransaction(
      id: updated.id,
      type: updated.type,
      amount: updated.amount,
      category: updated.category,
      note: updated.note,
      accountId: updated.accountId,
      toAccountId: updated.toAccountId,
      goalId: updated.goalId,
      frequency: updated.frequency,
      nextDueDate: nextDue,
      startDate: updated.startDate,
      endDate: updated.endDate,
      maxOccurrences: updated.maxOccurrences,
      isActive: updated.isActive,
    );
    await AppDatabase.updateRecurring(reset);

    await processRange(fromDate: reset.nextDueDate, toDate: today);
  }

  static Future<int> _processRecurringRules({
    required DateTime from,
    required DateTime to,
  }) async {
    int created = 0;
    final recurring = await AppDatabase.getRecurring();
    for (final rule in recurring) {
      if (!rule.isActive || rule.id == null) continue;

      var due = _atDayStart(rule.nextDueDate);
      final end = rule.endDate != null ? _atDayStart(rule.endDate!) : null;
      int existingCount = 0;
      if (rule.maxOccurrences != null) {
        existingCount = await _countExistingOccurrences(rule);
      }

      while (!due.isAfter(to)) {
        if (end != null && due.isAfter(end)) break;

        if (rule.maxOccurrences != null && existingCount >= rule.maxOccurrences!) {
          await AppDatabase.updateRecurring(
            RecurringTransaction(
              id: rule.id,
              type: rule.type,
              amount: rule.amount,
              category: rule.category,
              note: rule.note,
              accountId: rule.accountId,
              toAccountId: rule.toAccountId,
              goalId: rule.goalId,
              frequency: rule.frequency,
              nextDueDate: due,
              startDate: rule.startDate,
              endDate: rule.endDate,
              maxOccurrences: rule.maxOccurrences,
              isActive: false,
            ),
          );
          break;
        }

        if (!due.isBefore(from)) {
          final alreadyExecuted = await AppDatabase.hasExecutionLog(
            ruleType: recurringRuleType,
            ruleId: rule.id!,
            executionDate: due,
          );
          if (!alreadyExecuted) {
            final txId = await _executeRecurringRule(rule, due);
            if (txId != null) {
              created++;
              await AppDatabase.insertExecutionLog(
                ruleType: recurringRuleType,
                ruleId: rule.id!,
                executionDate: due,
                transactionId: txId,
              );
            }
          }
        }

        existingCount++;
        if (rule.frequency == 'once') {
          await AppDatabase.updateRecurring(
            RecurringTransaction(
              id: rule.id,
              type: rule.type,
              amount: rule.amount,
              category: rule.category,
              note: rule.note,
              accountId: rule.accountId,
              toAccountId: rule.toAccountId,
              goalId: rule.goalId,
              frequency: rule.frequency,
              nextDueDate: due.add(const Duration(days: 36500)),
              startDate: rule.startDate,
              endDate: rule.endDate,
              maxOccurrences: rule.maxOccurrences,
              isActive: false,
            ),
          );
          break;
        }
        due = _atDayStart(rule.nextAfter(due));
      }

      if (due.isAfter(rule.nextDueDate)) {
        await AppDatabase.updateRecurring(
          RecurringTransaction(
            id: rule.id,
            type: rule.type,
            amount: rule.amount,
            category: rule.category,
            note: rule.note,
            accountId: rule.accountId,
            toAccountId: rule.toAccountId,
            goalId: rule.goalId,
            frequency: rule.frequency,
            nextDueDate: due,
            startDate: rule.startDate,
            endDate: rule.endDate,
            maxOccurrences: rule.maxOccurrences,
            isActive: rule.isActive,
          ),
        );
      }
    }
    return created;
  }

  static Future<int> _processLoanRules({
    required DateTime from,
    required DateTime to,
  }) async {
    // Phase 2: loan tables + EMI execution.
    AppLogger.scheduler(
      'rule_engine.loan placeholder',
      detail: 'No loan rules registered yet ($from -> $to)',
    );
    return 0;
  }

  static Future<int> _countExistingOccurrences(RecurringTransaction rule) async {
    final d = await AppDatabase.db();
    final rows = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM transactions WHERE recurring_id = ? AND deleted_at IS NULL',
      [rule.id],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  static Future<int?> _executeRecurringRule(RecurringTransaction rule, DateTime date) async {
    if (rule.type == 'transfer') {
      if (rule.accountId == null || rule.toAccountId == null) return null;

      final debitId = await AppDatabase.insertTransaction(
        model.Transaction(
          type: 'expense',
          amount: rule.amount,
          category: 'transfer',
          note: 'recurring:${rule.id}',
          date: date,
          accountId: rule.accountId!,
          recurringId: rule.id,
          sourceType: 'recurring',
          fromAccountId: rule.accountId,
          toAccountId: rule.toAccountId,
          ruleType: recurringRuleType,
          referenceRuleId: rule.id,
        ),
      );
      await AppDatabase.insertTransaction(
        model.Transaction(
          type: 'income',
          amount: rule.amount,
          category: 'transfer',
          note: 'recurring:${rule.id}',
          date: date,
          accountId: rule.toAccountId!,
          recurringId: rule.id,
          sourceType: 'recurring',
          fromAccountId: rule.accountId,
          toAccountId: rule.toAccountId,
          ruleType: recurringRuleType,
          referenceRuleId: rule.id,
        ),
      );
      return debitId;
    }

    if (rule.accountId == null) return null;
    final txType = rule.type == 'goal' ? 'expense' : rule.type;
    return AppDatabase.insertTransaction(
      model.Transaction(
        type: txType,
        amount: rule.amount,
        category: rule.type == 'goal' ? 'savings' : rule.category,
        note: rule.note,
        date: date,
        accountId: rule.accountId!,
        recurringId: rule.id,
        sourceType: 'recurring',
        ruleType: recurringRuleType,
        referenceRuleId: rule.id,
      ),
    );
  }

  static DateTime _atDayStart(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime _firstDueOnOrAfter(RecurringTransaction rule, DateTime cutoff) {
    var due = _atDayStart(rule.startDate ?? rule.nextDueDate);
    final target = _atDayStart(cutoff);

    while (due.isBefore(target)) {
      if (rule.frequency == 'once') {
        return due.add(const Duration(days: 36500));
      }
      due = _atDayStart(rule.nextAfter(due));
    }
    return due;
  }

  static String _executionDateKey(DateTime date) {
    final d = _atDayStart(date);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
