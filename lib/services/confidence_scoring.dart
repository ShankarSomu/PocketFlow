import 'package:flutter/material.dart';

/// Confidence Scoring Service
/// Centralized confidence calculation for all SMS intelligence features
class ConfidenceScoring {
  // Confidence thresholds
  static const double thresholdHigh = 0.85;      // Auto-confirm
  static const double thresholdMedium = 0.70;    // Review recommended
  static const double thresholdLow = 0.50;       // User confirmation required
  
  /// Get confidence level label
  static String getConfidenceLevel(double confidence) {
    if (confidence >= thresholdHigh) return 'High';
    if (confidence >= thresholdMedium) return 'Medium';
    if (confidence >= thresholdLow) return 'Low';
    return 'Very Low';
  }

  /// Check if confidence is high enough for auto-confirmation
  static bool shouldAutoConfirm(double confidence) {
    return confidence >= thresholdHigh;
  }

  /// Check if confidence requires user review
  static bool requiresUserReview(double confidence) {
    return confidence < thresholdMedium;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENTITY EXTRACTION CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate confidence for extracted entities
  static double calculateExtractionConfidence({
    required bool hasAmount,
    required bool hasMerchant,
    required bool hasAccountIdentifier,
    required bool hasInstitution,
    required bool hasTimestamp,
    required bool hasReference,
    required bool hasTransactionType,
  }) {
    double confidence = 0.0;
    
    // Amount is critical (max 0.30)
    if (hasAmount) confidence += 0.30;
    
    // Account identifier is very important (max 0.25)
    if (hasAccountIdentifier) confidence += 0.25;
    
    // Institution name (max 0.20)
    if (hasInstitution) confidence += 0.20;
    
    // Merchant/description (max 0.10)
    if (hasMerchant) confidence += 0.10;
    
    // Transaction type (max 0.05)
    if (hasTransactionType) confidence += 0.05;
    
    // Reference number (max 0.05)
    if (hasReference) confidence += 0.05;
    
    // Timestamp (max 0.05)
    if (hasTimestamp) confidence += 0.05;
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT RESOLUTION CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate account match confidence
  static double calculateAccountMatchConfidence({
    required String matchMethod,
    bool hasInstitutionMatch = false,
    bool hasIdentifierMatch = false,
    bool hasKeywordMatch = false,
    bool hasHistoricalMatch = false,
    int historicalTransactionCount = 0,
  }) {
    double confidence = 0.0;
    
    switch (matchMethod) {
      case 'exact_identifier':
        confidence = 0.95; // Exact account identifier match
        break;
        
      case 'institution_partial':
        confidence = 0.80; // Institution + last 4 digits
        if (hasInstitutionMatch) confidence += 0.05;
        break;
        
      case 'sms_keyword':
        confidence = 0.70; // SMS keyword match
        if (hasKeywordMatch) confidence += 0.05;
        break;
        
      case 'historical_pattern':
        confidence = 0.60; // Based on transaction history
        // Bonus for more historical transactions
        if (historicalTransactionCount >= 10) {
          confidence += 0.10;
        } else if (historicalTransactionCount >= 5) {
          confidence += 0.05;
        }
        break;
        
      case 'new_candidate':
        confidence = 0.50; // New account candidate
        break;
        
      default:
        confidence = 0.30; // Unknown match method
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSFER DETECTION CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate transfer pair confidence
  static double calculateTransferConfidence({
    required bool amountMatch,
    required int minutesDifference,
    required bool referenceMatch,
    required bool bothMarkedAsTransfer,
    required bool sameAmountExact,
  }) {
    double confidence = 0.0;
    
    // Base confidence from amount match
    if (amountMatch) confidence += 0.40;
    
    // Time proximity bonus (max 0.30)
    if (minutesDifference == 0) {
      confidence += 0.30; // Same minute
    } else if (minutesDifference <= 5) {
      confidence += 0.25; // Within 5 minutes
    } else if (minutesDifference <= 30) {
      confidence += 0.20; // Within 30 minutes
    } else if (minutesDifference <= 60) {
      confidence += 0.15; // Within 1 hour
    } else {
      confidence += 0.10; // Within 2 hours
    }
    
    // Reference number match (max 0.20)
    if (referenceMatch) confidence += 0.20;
    
    // Transfer type indicators (max 0.10)
    if (bothMarkedAsTransfer) confidence += 0.10;
    
    // Exact amount match (max 0.05)
    if (sameAmountExact) confidence += 0.05;
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECURRING PATTERN CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate recurring pattern confidence
  static double calculateRecurringConfidence({
    required int occurrences,
    required double amountCoefficientOfVariation,
    required double intervalCoefficientOfVariation,
    required int intervalDays,
  }) {
    double confidence = 0.0;
    
    // Base confidence from occurrences (max 0.40)
    if (occurrences >= 12) {
      confidence += 0.40; // 1 year of data
    } else if (occurrences >= 6) {
      confidence += 0.30; // 6 months
    } else if (occurrences >= 3) {
      confidence += 0.20; // 3 occurrences
    }
    
    // Amount consistency bonus (max 0.30)
    if (amountCoefficientOfVariation < 0.02) {
      confidence += 0.30; // < 2% variation (very consistent)
    } else if (amountCoefficientOfVariation < 0.05) {
      confidence += 0.25; // < 5% variation
    } else if (amountCoefficientOfVariation < 0.10) {
      confidence += 0.20; // < 10% variation
    } else if (amountCoefficientOfVariation < 0.15) {
      confidence += 0.15; // < 15% variation
    }
    
    // Interval consistency bonus (max 0.30)
    if (intervalCoefficientOfVariation < 0.05) {
      confidence += 0.30; // Very regular intervals
    } else if (intervalCoefficientOfVariation < 0.10) {
      confidence += 0.25;
    } else if (intervalCoefficientOfVariation < 0.15) {
      confidence += 0.20;
    } else if (intervalCoefficientOfVariation < 0.25) {
      confidence += 0.15;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMS CLASSIFICATION CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate SMS classification confidence
  static double calculateClassificationConfidence({
    required int keywordMatchCount,
    required bool hasFinancialInstitutionSender,
    required bool hasTransactionIndicators,
    required bool hasAmountMention,
  }) {
    double confidence = 0.0;
    
    // Financial institution sender (max 0.40)
    if (hasFinancialInstitutionSender) confidence += 0.40;
    
    // Keyword matches (max 0.30)
    if (keywordMatchCount >= 3) {
      confidence += 0.30;
    } else if (keywordMatchCount == 2) {
      confidence += 0.20;
    } else if (keywordMatchCount == 1) {
      confidence += 0.10;
    }
    
    // Transaction indicators (max 0.20)
    if (hasTransactionIndicators) confidence += 0.20;
    
    // Amount mention (max 0.10)
    if (hasAmountMention) confidence += 0.10;
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MERCHANT NORMALIZATION CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate merchant normalization confidence
  static double calculateMerchantNormalizationConfidence({
    required bool exactAliasMatch,
    required bool partialAliasMatch,
    required bool genericNormalizationOnly,
    required double levenshteinSimilarity, // 0.0 to 1.0
  }) {
    double confidence = 0.0;
    
    if (exactAliasMatch) {
      confidence = 0.95; // Known exact alias
    } else if (partialAliasMatch) {
      confidence = 0.85; // Partial alias match
    } else if (genericNormalizationOnly) {
      confidence = 0.70; // Generic normalization rules only
    } else {
      // Use Levenshtein similarity
      confidence = 0.50 + (levenshteinSimilarity * 0.30);
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT CANDIDATE CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate account candidate confidence
  static double calculateCandidateConfidence({
    required int smsCount,
    required bool hasInstitutionName,
    required bool hasAccountIdentifier,
    required bool hasConsistentPattern,
    required int daysSinceFirstSeen,
  }) {
    double confidence = 0.0;
    
    // Base confidence from SMS count (max 0.30)
    if (smsCount >= 10) {
      confidence += 0.30;
    } else if (smsCount >= 5) {
      confidence += 0.25;
    } else if (smsCount >= 3) {
      confidence += 0.20;
    } else if (smsCount >= 2) {
      confidence += 0.15;
    } else {
      confidence += 0.10;
    }
    
    // Institution name present (max 0.25)
    if (hasInstitutionName) confidence += 0.25;
    
    // Account identifier present (max 0.25)
    if (hasAccountIdentifier) confidence += 0.25;
    
    // Consistent pattern over time (max 0.15)
    if (hasConsistentPattern) confidence += 0.15;
    
    // Time span bonus (max 0.05)
    if (daysSinceFirstSeen >= 30) {
      confidence += 0.05; // Seen over a month
    } else if (daysSinceFirstSeen >= 7) {
      confidence += 0.03; // Seen over a week
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMBINED PIPELINE CONFIDENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate overall SMS processing confidence
  static double calculatePipelineConfidence({
    required double privacyConfidence,      // 0.0 or 1.0 (blocked or allowed)
    required double classificationConfidence,
    required double extractionConfidence,
    required double accountResolutionConfidence,
  }) {
    // Privacy must pass (if failed, return 0)
    if (privacyConfidence < 1.0) return 0.0;
    
    // Weighted average
    final weights = {
      'classification': 0.20,
      'extraction': 0.30,
      'account_resolution': 0.50,
    };
    
    final weighted = 
        (classificationConfidence * weights['classification']!) +
        (extractionConfidence * weights['extraction']!) +
        (accountResolutionConfidence * weights['account_resolution']!);
    
    return weighted.clamp(0.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get color for confidence level (for UI)
  static Color getConfidenceColor(double confidence) {
    if (confidence >= thresholdHigh) return Colors.green;
    if (confidence >= thresholdMedium) return Colors.orange;
    if (confidence >= thresholdLow) return Colors.yellow.shade700;
    return Colors.red;
  }

  /// Get icon for confidence level (for UI)
  static IconData getConfidenceIcon(double confidence) {
    if (confidence >= thresholdHigh) return Icons.check_circle;
    if (confidence >= thresholdMedium) return Icons.warning;
    if (confidence >= thresholdLow) return Icons.help;
    return Icons.error;
  }

  /// Format confidence as percentage string
  static String formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  /// Get action recommendation based on confidence
  static String getRecommendedAction(double confidence) {
    if (confidence >= thresholdHigh) {
      return 'Auto-confirm - high confidence';
    } else if (confidence >= thresholdMedium) {
      return 'Review recommended - medium confidence';
    } else if (confidence >= thresholdLow) {
      return 'User confirmation required - low confidence';
    } else {
      return 'Manual entry recommended - very low confidence';
    }
  }

  /// Combine multiple confidence scores (weighted average)
  static double combineScores(Map<String, double> scores) {
    if (scores.isEmpty) return 0.0;
    
    // Equal weights if not specified
    final totalWeight = scores.length.toDouble();
    final sum = scores.values.reduce((a, b) => a + b);
    
    return (sum / totalWeight).clamp(0.0, 1.0);
  }

  /// Boost confidence based on user feedback
  static double boostWithUserFeedback({
    required double baseConfidence,
    required int userConfirmations,
    required int userRejections,
  }) {
    if (userConfirmations + userRejections == 0) {
      return baseConfidence;
    }
    
    final successRate = userConfirmations / (userConfirmations + userRejections);
    
    // Boost or reduce based on success rate
    if (successRate >= 0.90) {
      return (baseConfidence + 0.10).clamp(0.0, 1.0);
    } else if (successRate >= 0.75) {
      return (baseConfidence + 0.05).clamp(0.0, 1.0);
    } else if (successRate < 0.25) {
      return (baseConfidence - 0.10).clamp(0.0, 1.0);
    } else if (successRate < 0.50) {
      return (baseConfidence - 0.05).clamp(0.0, 1.0);
    }
    
    return baseConfidence;
  }
}
