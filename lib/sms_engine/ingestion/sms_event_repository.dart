import 'package:pocket_flow/db/database.dart';

/// Processing status for an [sms_events] row.
enum SmsEventStatus {
  pending('pending'),
  processed('processed'),
  skipped('skipped'),
  duplicate('duplicate'),
  blocked('blocked');

  const SmsEventStatus(this.value);
  final String value;

  static SmsEventStatus fromValue(String v) =>
      SmsEventStatus.values.firstWhere((e) => e.value == v,
          orElse: () => SmsEventStatus.pending);
}

/// Repository for the [sms_events] table.
///
/// Every incoming SMS is logged here before pipeline processing, providing
/// an audit trail and enabling content-hash deduplication.
class SmsEventRepository {
  /// Insert a new [sms_events] row. Returns the auto-generated row id.
  Future<int> insert({
    required String rawBody,
    required String sender,
    required DateTime receivedAt,
    required String contentHash,
    SmsEventStatus status = SmsEventStatus.pending,
    int? transactionId,
  }) async {
    final db = await AppDatabase.db();
    return db.insert('sms_events', {
      'raw_body': rawBody,
      'sender': sender,
      'received_at': receivedAt.toIso8601String(),
      'content_hash': contentHash,
      'processing_status': status.value,
      if (transactionId != null) 'transaction_id': transactionId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns the existing row id if a row with [contentHash] already exists,
  /// or `null` if this is a new (non-duplicate) SMS.
  Future<int?> findIdByHash(String contentHash) async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'sms_events',
      columns: ['id'],
      where: 'content_hash = ?',
      whereArgs: [contentHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  /// Update [processing_status] for an existing row.
  /// Optionally sets [transaction_id] when the pipeline produced a transaction.
  Future<void> updateStatus(
    int id,
    SmsEventStatus status, {
    int? transactionId,
  }) async {
    final db = await AppDatabase.db();
    await db.update(
      'sms_events',
      {
        'processing_status': status.value,
        if (transactionId != null) 'transaction_id': transactionId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
