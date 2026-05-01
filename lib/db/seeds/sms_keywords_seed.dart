import 'package:sqflite/sqflite.dart';

/// SMS Keywords Seed — intentionally empty.
///
/// The `sms_keywords` table starts empty. Sender IDs are learned organically:
///   1. Unknown sender + financial body signal → passes as unknownFinancial
///   2. User confirms the transaction
///   3. [TransactionFeedbackService._learnSender] writes the sender ID to
///      `sms_keywords` with type = 'sender_pattern'
///   4. All future messages from that sender pass the gate directly (Tier 1)
///
/// There is no pre-seeding of short codes or text sender IDs.
/// No hardcoding. The feedback system owns the sender list entirely.
class SmsKeywordsSeed {
  /// No-op — table starts empty, senders are learned from user confirmations.
  static Future<void> seedSenderPatterns(Database db) async {}

  /// No-op — keyword classification is handled by the ML model.
  static Future<void> seedKeywords(Database db) async {}

  /// No-op — merchant categories are learned from user corrections.
  static Future<void> seedMerchantCategories(Database db) async {}
}
