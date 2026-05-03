import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart';
import 'app_logger.dart';

/// Result of running the SMS classifier.
class MlClassificationResult {
  const MlClassificationResult({
    required this.label,
    required this.confidence,
  });

  /// One of: debit | credit | transfer | balance | reminder | non_financial
  final String label;

  /// Model confidence in [0.0, 1.0].
  final double confidence;

  @override
  String toString() =>
      'MlClassificationResult(label: $label, confidence: ${confidence.toStringAsFixed(3)})';
}

/// On-device SMS classifier backed by a TFLite model.
///
/// Lifecycle:
///   1. Call [initialize] once at app startup (or lazily on first use).
///   2. Call [classify] for each SMS body.
///   3. Call [dispose] when the app is shutting down.
///
/// The model is a 6-way text classifier:
///   0 debit | 1 credit | 2 transfer | 3 balance | 4 reminder | 5 non_financial
class SmsClassifierService {
  static const _modelAsset     = 'ml/sms_classifier.tflite';
  static const _tokenizerAsset = 'assets/ml/tokenizer_config.json';

  static Interpreter? _interpreter;
  static Map<String, int>? _wordIndex;
  static int _maxLen    = 64;
  static int _vocabSize = 4000;

  static const _indexToLabel = {
    0: 'debit',
    1: 'credit',
    2: 'transfer',
    3: 'balance',
    4: 'reminder',
    5: 'non_financial',
  };

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Load the TFLite model and tokenizer from assets.
  /// Safe to call multiple times — subsequent calls are no-ops.
  static Future<void> initialize() async {
    if (_interpreter != null) return;

    AppLogger.sms('ML init', detail: 'loading model + tokenizer');
    // Load tokenizer config
    final tokenizerJson =
        await rootBundle.loadString(_tokenizerAsset);
    final config = json.decode(tokenizerJson) as Map<String, dynamic>;

    _wordIndex = Map<String, int>.from(
      (config['word_index'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
    );
    _maxLen    = (config['max_len']    as num).toInt();
    _vocabSize = (config['vocab_size'] as num).toInt();

    // Load TFLite model
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    AppLogger.sms('ML ready', detail: 'vocab=${_wordIndex?.length} maxLen=$_maxLen');
  }

  /// Release interpreter resources.
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _wordIndex   = null;
  }

  // ── Inference ───────────────────────────────────────────────────────────────

  /// Classify [smsBody] and return the predicted label + confidence.
  ///
  /// Initialises automatically if [initialize] has not been called yet.
  /// Returns `non_financial` with confidence 0.0 on any error.
  static Future<MlClassificationResult> classify(String smsBody) async {
    try {
      if (_interpreter == null) await initialize();

      final input  = _tokenize(smsBody);
      final output = List.filled(6, 0.0).reshape([1, 6]);

      _interpreter!.run(input, output);

      final probs = List<double>.from(output[0] as List);
      final maxIdx = probs.indexOf(probs.reduce(math.max));
      final label  = _indexToLabel[maxIdx] ?? 'non_financial';

      AppLogger.sms('ML result', detail: 'label=$label conf=${probs[maxIdx].toStringAsFixed(3)} body="${smsBody.substring(0, smsBody.length > 60 ? 60 : smsBody.length)}"');

      return MlClassificationResult(
        label:      label,
        confidence: probs[maxIdx],
      );
    } catch (e) {
      // Fail safe — return non_financial so the pipeline drops the message
      // rather than crashing.
      AppLogger.sms(
        'ML error',
        detail: e.toString(),
        level: LogLevel.error,
      );
      return const MlClassificationResult(
        label:      'non_financial',
        confidence: 0.0,
      );
    }
  }

  // ── Tokenization ────────────────────────────────────────────────────────────

  /// Tokenize and pad [text] to a [1 × _maxLen] int32 tensor.
  static List<List<double>> _tokenize(String text) {
    final cleaned = _clean(text);
    final words   = cleaned.split(' ').where((w) => w.isNotEmpty).toList();

    final oovIdx = _wordIndex?['<OOV>'] ?? 1;

    // Map words → indices (OOV for unknown, cap at vocab size)
    final indices = words.map((w) {
      final idx = _wordIndex?[w] ?? oovIdx;
      return idx < _vocabSize ? idx : oovIdx;
    }).toList();

    // Post-pad / truncate to maxLen
    final padded = List<double>.filled(_maxLen, 0);
    final copyLen = math.min(indices.length, _maxLen);
    for (var i = 0; i < copyLen; i++) {
      padded[i] = indices[i].toDouble();
    }

    return [padded]; // shape [1, maxLen]
  }

  /// Mirror the cleaning applied during training.
  static String _clean(String text) {
    var t = text.toLowerCase();
    // Normalise dollar amounts
    t = t.replaceAll(RegExp(r'\$[\d,]+(?:\.\d{1,2})?'), '\$amount');
    // Normalise account last-4
    t = t.replaceAll(RegExp(r'\b\d{4}\b'), 'acct1234');
    // Normalise dates  mm/dd/yyyy
    t = t.replaceAll(RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}'), 'date');
    // Normalise month-name dates
    t = t.replaceAll(
      RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+\d{1,2}(,\s*\d{4})?',
        caseSensitive: false,
      ),
      'date',
    );
    // Remove URLs
    t = t.replaceAll(RegExp(r'https?://\S+'), '');
    // Remove punctuation
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }
}
