import 'dart:convert';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import 'app_logger.dart';

// ── SMS Scan Settings Keys ────────────────────────────────────────────────────
const _kSmsEnabled = 'sms_enabled';
const _kSmsScanRange = 'sms_scan_range';       // 'all' | '6m' | '3m' | '1m' | '1w'
const _kSmsLastScan = 'sms_last_scan';
const _kSmsProcessed = 'sms_processed_ids';    // JSON set of processed SMS IDs

/// How far back to look when scanning SMS.
enum SmsScanRange {
  allTime('all', 'All messages'),
  sixMonths('6m', 'Last 6 months'),
  threeMonths('3m', 'Last 3 months'),
  oneMonth('1m', 'Last 1 month'),
  oneWeek('1w', 'Last 1 week');

  final String key;
  final String label;
  const SmsScanRange(this.key, this.label);

  static SmsScanRange fromKey(String k) =>
      SmsScanRange.values.firstWhere((e) => e.key == k, orElse: () => SmsScanRange.oneMonth);

  DateTime? get cutoff {
    final now = DateTime.now();
    switch (this) {
      case SmsScanRange.allTime:
        return null;
      case SmsScanRange.sixMonths:
        return now.subtract(const Duration(days: 183));
      case SmsScanRange.threeMonths:
        return now.subtract(const Duration(days: 91));
      case SmsScanRange.oneMonth:
        return now.subtract(const Duration(days: 30));
      case SmsScanRange.oneWeek:
        return now.subtract(const Duration(days: 7));
    }
  }
}

// ── Financial SMS patterns ────────────────────────────────────────────────────

/// Regex for extracting amount. Handles:
/// $1,234.56 | USD 1234 | Rs.1,000 | INR 500 | ₹500 | RM 25 | AED 50
final _amountRe = RegExp(
  r'(?:(?:USD|INR|Rs\.?|₹|RM|AED|GBP|EUR|SGD|CAD|AUD|HKD)\s*)?'
  r'([\d,]+(?:\.\d{1,2})?)'
  r'(?:\s*(?:USD|INR|Rs|₹))?',
  caseSensitive: false,
);

/// Debit keywords → expense
const _debitKeywords = [
  'debited', 'deducted', 'spent', 'paid', 'payment of', 'purchase',
  'withdrawn', 'charged', 'transaction of', 'used at', 'txn of',
  'amount of rs', 'amt rs', 'transaction amt', 'payment done',
];

/// Credit keywords → income
const _creditKeywords = [
  'credited', 'received', 'deposited', 'refund', 'cashback',
  'salary', 'credit of', 'amount credited', 'added to',
];

/// Financial sender IDs (short codes, alphanumeric senders)
final _bankSenderRe = RegExp(
  '^(?:AD-|BZ-|VK-|AX-|JD-|HD-|SB-|IC-|KO-|UN-|CX-|AM-)?'
  '(?:HDFCBK|ICICIBK|SBIINB|AXISBK|KOTAKB|PNBSMS|BOBIMT|CITIBK|'
  'SCBANK|HSBCIN|RBLBK|YESBK|IDFCBK|AUBANK|FEDERAL|INDUSIND|'
  'CANBNK|BOIIND|UNIONBK|SYNDICBK|BANDHAN|JPBANK|DBANK|AMEXIN|'
  'PAYTM|GPAY|PHONEPE|AMAZONP|FREECHARGE|MOBIKWIK|BAJAJFIN)',
  caseSensitive: false,
);

/// Merchant name extractors — captures "at MERCHANT" or "to MERCHANT"
final _merchantAtRe = RegExp(r"\bat\s+([A-Za-z0-9 &\-'\.]{3,40})", caseSensitive: false);
final _merchantToRe = RegExp(r"\bto\s+([A-Za-z0-9 &\-'\.]{3,40})", caseSensitive: false);
final _merchantForRe = RegExp(r"\bfor\s+([A-Za-z0-9 &\-'\.]{3,40})", caseSensitive: false);

// ── Category mapping from merchant keywords ───────────────────────────────────

const _merchantCategoryMap = <String, String>{
  // 🛒 Groceries / Supermarkets
  'walmart': 'Groceries', 'target': 'Shopping', 'costco': 'Groceries',
  'kroger': 'Groceries', 'safeway': 'Groceries', 'whole foods': 'Groceries',
  'dmart': 'Groceries', 'bigbasket': 'Groceries', 'blinkit': 'Groceries',
  'zepto': 'Groceries', 'swiggy instamart': 'Groceries',
  'reliance fresh': 'Groceries', 'more': 'Groceries',

  // 🍔 Food / Dining
  'swiggy': 'Dining Out', 'zomato': 'Dining Out', 'uber eats': 'Dining Out',
  'doordash': 'Dining Out', 'grubhub': 'Dining Out', 'mcdonalds': 'Dining Out',
  'mcdonald': 'Dining Out', 'kfc': 'Dining Out', 'subway': 'Dining Out',
  'pizza hut': 'Dining Out', 'dominos': 'Dining Out', 'domino': 'Dining Out',
  'starbucks': 'Coffee', 'dunkin': 'Coffee', 'costa': 'Coffee',

  // 🚗 Transport
  'uber': 'Transport', 'ola': 'Transport', 'lyft': 'Transport',
  'rapido': 'Transport', 'grab': 'Transport', 'gojek': 'Transport',
  'irctc': 'Transport', 'makemytrip': 'Travel', 'goibibo': 'Travel',
  'redbus': 'Transport', 'yulu': 'Transport', 'shell': 'Fuel',
  'bp': 'Fuel', 'iocl': 'Fuel', 'hpcl': 'Fuel', 'bpcl': 'Fuel',
  'petrol': 'Fuel', 'pump': 'Fuel',

  // 🛍️ Shopping / E-commerce
  'amazon': 'Shopping', 'flipkart': 'Shopping', 'myntra': 'Shopping',
  'meesho': 'Shopping', 'ajio': 'Shopping', 'nykaa': 'Beauty',
  'alibaba': 'Shopping', 'aliexpress': 'Shopping', 'ebay': 'Shopping',
  'shopify': 'Shopping', 'zara': 'Clothing', 'h&m': 'Clothing',
  'uniqlo': 'Clothing', 'gap': 'Clothing',

  // 🏥 Health / Medical
  'pharmacy': 'Pharmacy', 'apollo': 'Pharmacy', 'medplus': 'Pharmacy',
  '1mg': 'Pharmacy', 'netmeds': 'Pharmacy', 'hospital': 'Doctor',
  'clinic': 'Doctor', 'dental': 'Dental', 'gym': 'Gym',
  'cult.fit': 'Gym', 'cultsport': 'Gym', 'healthkart': 'Gym',

  // 📺 Entertainment / Streaming
  'netflix': 'Streaming', 'spotify': 'Streaming', 'hotstar': 'Streaming',
  'jio cinema': 'Streaming', 'amazon prime': 'Streaming', 'prime video': 'Streaming',
  'apple tv': 'Streaming', 'youtube premium': 'Streaming',
  'disney': 'Streaming', 'zee5': 'Streaming', 'sonyliv': 'Streaming',
  'bookmyshow': 'Movies', 'pvr': 'Movies', 'inox': 'Movies',
  'steam': 'Games', 'playstation': 'Games', 'xbox': 'Games',

  // 📱 Bills / Utilities
  'airtel': 'Phone', 'jio': 'Phone', 'vodafone': 'Phone', 'vi': 'Phone',
  'bsnl': 'Phone', 'act fibernet': 'Internet', 'hathway': 'Internet',
  'electricity': 'Utilities', 'bescom': 'Utilities', 'mahadiscom': 'Utilities',
  'water bill': 'Utilities', 'gas bill': 'Utilities', 'lpg': 'Utilities',

  // ✈️ Travel
  'indigo': 'Flights', 'air india': 'Flights', 'spicejet': 'Flights',
  'vistara': 'Flights', 'emirates': 'Flights', 'booking.com': 'Hotels',
  'oyo': 'Hotels', 'hotels.com': 'Hotels', 'airbnb': 'Hotels',
  'agoda': 'Hotels',

  // 💰 Finance / Insurance
  'lic': 'Insurance', 'hdfc life': 'Insurance', 'star health': 'Insurance',
  'policybazaar': 'Insurance', 'navi': 'Insurance',
  'zerodha': 'Investment', 'groww': 'Investment', 'upstox': 'Investment',
  'coinbase': 'Investment', 'binance': 'Investment',

  // 🏠 Housing / Rent
  'rent': 'Rent', 'nobroker': 'Rent', 'magicbricks': 'Rent',
  'maintenance': 'Repairs', 'society': 'Repairs',
};

String _guessCategoryFromMerchant(String merchant) {
  final lower = merchant.toLowerCase();
  for (final entry in _merchantCategoryMap.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'Other';
}

// ── SmsService ────────────────────────────────────────────────────────────────

class SmsService {
  // ── Settings ────────────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSmsEnabled) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmsEnabled, v);
  }

  static Future<SmsScanRange> getScanRange() async {
    final p = await SharedPreferences.getInstance();
    return SmsScanRange.fromKey(p.getString(_kSmsScanRange) ?? 'all');
  }

  static Future<void> setScanRange(SmsScanRange r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsScanRange, r.key);
  }

  static Future<DateTime?> getLastScan() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSmsLastScan);
    return s != null ? DateTime.tryParse(s) : null;
  }

  static Future<void> _setLastScan(DateTime dt) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSmsLastScan, dt.toIso8601String());
  }

  static Future<Set<int>> _getProcessedIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSmsProcessed);
    if (raw == null) return {};
    final List decoded = jsonDecode(raw);
    return decoded.cast<int>().toSet();
  }

  static Future<void> _saveProcessedIds(Set<int> ids) async {
    final p = await SharedPreferences.getInstance();
    // Keep only latest 5000 to avoid unbounded growth
    final trimmed = ids.length > 5000 ? ids.skip(ids.length - 5000).toSet() : ids;
    await p.setString(_kSmsProcessed, jsonEncode(trimmed.toList()));
  }

  // ── Permission ───────────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<bool> hasPermission() async {
    return Permission.sms.isGranted;
  }

  // ── Main scan ────────────────────────────────────────────────────────────────

  /// Reads SMS inbox, parses financial messages, inserts new transactions.
  /// Returns [SmsImportResult] with stats.
  static Future<SmsImportResult> scanAndImport({bool force = false}) async {
    if (!await hasPermission()) {
      return const SmsImportResult(error: 'SMS permission not granted');
    }

    final range = await getScanRange();
    final cutoff = range.cutoff;

    final query = SmsQuery();
    final List<SmsMessage> allMessages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
    );

    final processedIds = await _getProcessedIds();
    int imported = 0;
    int skipped = 0;
    int failed = 0;
    final newIds = <int>{};

    for (final sms in allMessages) {
      try {
        final id = sms.id;
        if (id == null) continue;

        // Time range filter
        final date = sms.date;
        if (cutoff != null && date != null && date.isBefore(cutoff)) continue;

        // Skip already processed
        if (processedIds.contains(id)) { skipped++; continue; }

        // Only process financial SMS
        final body = sms.body ?? '';
        if (!_isFinancialSms(body, sms.sender ?? '')) { skipped++; continue; }

        final parsed = _parseSms(body, date ?? DateTime.now());
        if (parsed == null) { skipped++; continue; }

        // Store SMS source in transaction
        final transaction = model.Transaction(
          type: parsed.type,
          amount: parsed.amount,
          category: parsed.category,
          note: parsed.note,
          date: parsed.date,
          accountId: parsed.accountId,
          smsSource: body, // Store original SMS text
        );

        await AppDatabase.insertTransaction(transaction);
        newIds.add(id);
        imported++;
      } catch (e) {
        AppLogger.err('sms_import', e);
        failed++;
      }
    }

    // Persist processed IDs
    processedIds.addAll(newIds);
    await _saveProcessedIds(processedIds);
    await _setLastScan(DateTime.now());

    return SmsImportResult(imported: imported, skipped: skipped, failed: failed);
  }

  // ── Parsing helpers ──────────────────────────────────────────────────────────

  static bool _isFinancialSms(String body, String sender) {
    final lower = body.toLowerCase();
    // Must contain an amount-like pattern
    if (!_amountRe.hasMatch(lower)) return false;
    // Must contain at least one debit/credit keyword
    for (final k in [..._debitKeywords, ..._creditKeywords]) {
      if (lower.contains(k)) return true;
    }
    // Or the sender looks like a bank
    if (_bankSenderRe.hasMatch(sender)) return true;
    return false;
  }

  static model.Transaction? _parseSms(String body, DateTime date) {
    final lower = body.toLowerCase();

    // Determine type
    String type = 'expense';
    for (final k in _creditKeywords) {
      if (lower.contains(k)) { type = 'income'; break; }
    }

    // Extract amount — pick the largest plausible amount
    double? amount;
    for (final m in _amountRe.allMatches(body)) {
      final raw = m.group(1)?.replaceAll(',', '');
      final v = double.tryParse(raw ?? '');
      if (v != null && v > 0 && v < 10000000) {
        if (amount == null || v > amount) amount = v;
      }
    }
    if (amount == null || amount <= 0) return null;

    // Extract merchant
    String merchant = '';
    final atMatch = _merchantAtRe.firstMatch(body);
    final toMatch = _merchantToRe.firstMatch(body);
    final forMatch = _merchantForRe.firstMatch(body);

    if (atMatch != null) {
      merchant = atMatch.group(1)?.trim() ?? '';
    } else if (type == 'expense' && toMatch != null) merchant = toMatch.group(1)?.trim() ?? '';
    else if (type == 'income' && toMatch != null) merchant = toMatch.group(1)?.trim() ?? '';
    else if (forMatch != null) merchant = forMatch.group(1)?.trim() ?? '';

    // Clean up merchant (remove trailing garbage)
    merchant = merchant.replaceAll(RegExp(r'[.\s]+$'), '').trim();
    if (merchant.length < 2) merchant = '';

    final category = merchant.isNotEmpty
        ? _guessCategoryFromMerchant(merchant)
        : (type == 'income' ? 'Salary' : 'Other');

    final note = merchant.isNotEmpty
        ? '📱 SMS: $merchant'
        : '📱 SMS Import';

    return model.Transaction(
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class SmsImportResult {

  const SmsImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.failed = 0,
    this.error,
  });
  final int imported;
  final int skipped;
  final int failed;
  final String? error;

  bool get hasError => error != null;

  @override
  String toString() =>
      error ?? 'Imported: $imported  •  Skipped: $skipped  •  Failed: $failed';
}
