import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as model;
import 'unified_rule_engine.dart';

class RecurringScheduler {
  /// Backward-compatible wrapper around the unified rule engine.
  static Future<int> processDue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return UnifiedRuleEngine.processRange(fromDate: today, toDate: today);
  }

  /// Backward-compatible edit hook.
  static Future<void> onUpdated(
    RecurringTransaction updated, {
    bool rewritePastTransactions = true,
    DateTime? effectiveFromDate,
  }) async {
    await UnifiedRuleEngine.onRecurringRuleUpdated(
      updated,
      rewritePastTransactions: rewritePastTransactions,
      effectiveFromDate: effectiveFromDate,
    );
  }

  static Future<List<model.Transaction>> simulateTime({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return UnifiedRuleEngine.simulateTime(fromDate: fromDate, toDate: toDate);
  }
}
