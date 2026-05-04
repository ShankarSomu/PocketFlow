import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Normalizes raw SMS text to a canonical form for structural matching and
/// content-hash deduplication.
///
/// The canonical form strips noise (URLs, specific amounts, masked account
/// numbers, dates) so that two SMS messages that convey the same event but
/// differ only in the exact dollar amount or date produce the same hash.
class SmsNormalizer {
  // Matches http/https URLs and bare www. URLs
  static final _urlRe = RegExp(
    r'https?://\S+|www\.\S+',
    caseSensitive: false,
  );

  // Matches currency amounts in common formats:
  // $1,234.56  ₹500  Rs.100  INR 500  100 Rs  etc.
  static final _amountRe = RegExp(
    r'(?:rs\.?|inr|usd|aud|gbp|eur|sgd|cad|hkd|aed|rm|₹|\$)\s*\d[\d,]*(?:\.\d{1,2})?'
    r'|\d[\d,]*(?:\.\d{1,2})?\s*(?:rs\.?|inr)',
    caseSensitive: false,
  );

  // Matches dates: DD/MM/YYYY, DD-MM-YY, Jan 3 2024, etc.
  static final _dateRe = RegExp(
    r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b'
    r'|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\.?\s+\d{1,2},?\s+\d{4}\b',
    caseSensitive: false,
  );

  // Matches masked account numbers: XXXX1234, **1234, 1234XXXX
  static final _acctRe = RegExp(
    r'\b[xX*]{2,}\d{2,6}\b|\b\d{2,6}[xX*]{2,}\b',
  );

  static final _whitespaceRe = RegExp(r'\s+');

  /// Return the canonical (normalized) form of [body].
  static String normalize(String body) {
    var s = body.toLowerCase();
    s = s.replaceAll(_urlRe, 'URL_TOKEN');
    s = s.replaceAll(_amountRe, 'AMT_TOKEN');
    s = s.replaceAll(_dateRe, 'DATE_TOKEN');
    s = s.replaceAll(_acctRe, 'ACCT_TOKEN');
    s = s.replaceAll(_whitespaceRe, ' ').trim();
    return s;
  }

  /// Compute a SHA-256 hash of [normalizedBody] combined with [sender].
  ///
  /// Two SMS messages with the same normalized text from the same sender
  /// produce the same hash, enabling template clustering.
  static String computeHash(String normalizedBody, String sender) {
    final input = '${sender.toLowerCase().trim()}|$normalizedBody';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Compute a SHA-256 hash for **deduplication** using the raw (un-token-masked)
  /// sanitized body. Only the exact same message body from the same sender
  /// will produce a matching hash — different amounts or dates will NOT match.
  static String computeDedupeHash(String sanitizedBody, String sender) {
    // Minimal normalization: lowercase + collapse whitespace only
    final normalized =
        sanitizedBody.toLowerCase().replaceAll(_whitespaceRe, ' ').trim();
    final input = '${sender.toLowerCase().trim()}|$normalized';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
