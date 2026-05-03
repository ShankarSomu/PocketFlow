import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_signature.dart';

/// Re-evaluates all needs_review SMS transactions using structural similarity.
/// NO keyword matching. Uses sender + pattern type + structure scoring.
class SmsReevaluationService {

  static Future<ReevaluationResult> reevaluateAll() async {
    final db = await AppDatabase.db();

    // Load all needs_review SMS transactions with SMS source
    final rows = await db.query(
      'transactions',
      where: "needs_review = 1 AND source_type = 'sms' AND sms_source IS NOT NULL AND deleted_at IS NULL",
    );

    if (rows.isEmpty) {
      return const ReevaluationResult(checked: 0, deleted: 0, categorized: 0, unchanged: 0);
    }

    // Load all negative samples
    final negativeRows = await db.query('sms_negative_samples');
    final negativeSamples = negativeRows.map(SmsSignature.fromMap).toList();

    int deleted = 0;
    int categorized = 0;
    int unchanged = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      final tx = model.Transaction.fromMap(row);
      if (tx.smsSource == null) continue;

      // Build structural signature using transaction type as ML label hint
      // type=expense → debit, type=income → credit, type=transfer → transfer
      final mlHint = tx.type == 'expense' ? 'debit'
          : tx.type == 'income' ? 'credit'
          : tx.type == 'transfer' ? 'transfer'
          : null;
      final sig = SmsSignature.from(tx.smsSource!, tx.extractedBank, mlLabel: mlHint);

      // Check against all negative samples
      bool isBlocked = false;
      for (final neg in negativeSamples) {
        if (sig.similarityTo(neg) >= 0.7) {
          isBlocked = true;
          break;
        }
      }

      if (isBlocked) {
        await db.update(
          'transactions',
          {'deleted_at': now},
          where: 'id = ?',
          whereArgs: [tx.id],
        );
        deleted++;
        AppLogger.log(LogLevel.debug, LogCategory.system,
            'reevaluate: deleted tx ${tx.id} (structural match to negative sample)');
      } else {
        unchanged++;
      }
    }

    AppLogger.log(LogLevel.info, LogCategory.system, 'reevaluate complete',
        detail: 'checked=${rows.length} deleted=$deleted unchanged=$unchanged');

    return ReevaluationResult(
      checked: rows.length,
      deleted: deleted,
      categorized: categorized,
      unchanged: unchanged,
    );
  }
}

class ReevaluationResult {
  const ReevaluationResult({
    required this.checked,
    required this.deleted,
    required this.categorized,
    required this.unchanged,
  });

  final int checked;
  final int deleted;
  final int categorized;
  final int unchanged;

  int get resolved => deleted + categorized;

  String get summary {
    if (checked == 0) return 'No pending transactions to re-evaluate.';
    final parts = <String>[];
    if (deleted > 0) parts.add('$deleted removed');
    if (categorized > 0) parts.add('$categorized auto-categorized');
    if (unchanged > 0) parts.add('$unchanged still need review');
    return parts.join(' • ');
  }
}
