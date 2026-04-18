import 'package:pocket_flow/models/transaction.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/budget.dart';
import 'package:pocket_flow/models/savings_goal.dart';
import 'package:pocket_flow/models/recurring_transaction.dart';

/// Supported export formats
enum ExportFormat {
  json,
  csv,
  excel,
  pdf;

  String get displayName {
    switch (this) {
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.excel:
        return 'Excel';
      case ExportFormat.pdf:
        return 'PDF Report';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.json:
        return 'json';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.pdf:
        return 'pdf';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.excel:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }
}

/// Data types that can be included in export
enum ExportDataType {
  transactions,
  accounts,
  budgets,
  savingsGoals,
  recurringTransactions;

  String get displayName {
    switch (this) {
      case ExportDataType.transactions:
        return 'Transactions';
      case ExportDataType.accounts:
        return 'Accounts';
      case ExportDataType.budgets:
        return 'Budgets';
      case ExportDataType.savingsGoals:
        return 'Savings Goals';
      case ExportDataType.recurringTransactions:
        return 'Recurring Transactions';
    }
  }
}

/// Configuration for export operation
class ExportConfig {
  final ExportFormat format;
  final List<ExportDataType> dataTypes;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? categoryFilter;
  final List<int>? accountFilter;
  final bool includeDeleted;
  final bool includeMetadata;
  final String? customFileName;

  const ExportConfig({
    required this.format,
    this.dataTypes = const [
      ExportDataType.transactions,
      ExportDataType.accounts,
      ExportDataType.budgets,
      ExportDataType.savingsGoals,
    ],
    this.startDate,
    this.endDate,
    this.categoryFilter,
    this.accountFilter,
    this.includeDeleted = false,
    this.includeMetadata = true,
    this.customFileName,
  });

  /// Get default filename based on format and date range
  String getFileName() {
    if (customFileName != null && customFileName!.isNotEmpty) {
      return '$customFileName.${format.fileExtension}';
    }

    final dateStr = startDate != null && endDate != null
        ? '${_formatDate(startDate!)}_to_${_formatDate(endDate!)}'
        : _formatDate(DateTime.now());

    return 'pocketflow_export_$dateStr.${format.fileExtension}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  ExportConfig copyWith({
    ExportFormat? format,
    List<ExportDataType>? dataTypes,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categoryFilter,
    List<int>? accountFilter,
    bool? includeDeleted,
    bool? includeMetadata,
    String? customFileName,
  }) {
    return ExportConfig(
      format: format ?? this.format,
      dataTypes: dataTypes ?? this.dataTypes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      accountFilter: accountFilter ?? this.accountFilter,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      customFileName: customFileName ?? this.customFileName,
    );
  }
}

/// Container for all exportable data
class ExportData {
  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<Budget> budgets;
  final List<SavingsGoal> savingsGoals;
  final List<RecurringTransaction> recurringTransactions;
  final ExportMetadata metadata;

  const ExportData({
    this.transactions = const [],
    this.accounts = const [],
    this.budgets = const [],
    this.savingsGoals = const [],
    this.recurringTransactions = const [],
    required this.metadata,
  });

  /// Convert to JSON-serializable map
  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'budgets': budgets.map((b) => b.toMap()).toList(),
      'savings_goals': savingsGoals.map((g) => g.toMap()).toList(),
      'recurring_transactions': recurringTransactions.map((r) => r.toMap()).toList(),
      'metadata': metadata.toJson(),
    };
  }

  /// Get total count of all items
  int get totalItems =>
      transactions.length +
      accounts.length +
      budgets.length +
      savingsGoals.length +
      recurringTransactions.length;

  /// Check if export is empty
  bool get isEmpty => totalItems == 0;
}

/// Metadata about the export
class ExportMetadata {
  final String appVersion;
  final DateTime exportDate;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final int transactionCount;
  final int accountCount;
  final int budgetCount;
  final int savingsGoalCount;
  final int recurringTransactionCount;
  final double totalIncome;
  final double totalExpense;
  final double netAmount;
  final List<String> includedCategories;
  final List<int> includedAccounts;

  const ExportMetadata({
    required this.appVersion,
    required this.exportDate,
    this.dateRangeStart,
    this.dateRangeEnd,
    required this.transactionCount,
    required this.accountCount,
    required this.budgetCount,
    required this.savingsGoalCount,
    required this.recurringTransactionCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
    this.includedCategories = const [],
    this.includedAccounts = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'app_version': appVersion,
      'export_date': exportDate.toIso8601String(),
      'date_range_start': dateRangeStart?.toIso8601String(),
      'date_range_end': dateRangeEnd?.toIso8601String(),
      'counts': {
        'transactions': transactionCount,
        'accounts': accountCount,
        'budgets': budgetCount,
        'savings_goals': savingsGoalCount,
        'recurring_transactions': recurringTransactionCount,
      },
      'summary': {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'net_amount': netAmount,
      },
      'filters': {
        'categories': includedCategories,
        'accounts': includedAccounts,
      },
    };
  }
}

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final int? fileSize;
  final String? error;
  final ExportFormat format;
  final DateTime timestamp;
  final Duration duration;

  const ExportResult({
    required this.success,
    this.filePath,
    this.fileSize,
    this.error,
    required this.format,
    required this.timestamp,
    required this.duration,
  });

  /// Create a successful result
  factory ExportResult.success({
    required String filePath,
    required int fileSize,
    required ExportFormat format,
    required Duration duration,
  }) {
    return ExportResult(
      success: true,
      filePath: filePath,
      fileSize: fileSize,
      format: format,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }

  /// Create a failed result
  factory ExportResult.failure({
    required String error,
    required ExportFormat format,
    required Duration duration,
  }) {
    return ExportResult(
      success: false,
      error: error,
      format: format,
      timestamp: DateTime.now(),
      duration: duration,
    );
  }

  /// Get human-readable file size
  String get formattedSize {
    if (fileSize == null) return 'Unknown';
    
    if (fileSize! < 1024) {
      return '$fileSize B';
    } else if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get fileName => filePath?.split('/').last ?? 'export';

  /// Get human-readable duration
  String get formattedDuration {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds}ms';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// CSV column configuration
class CsvColumnConfig {
  final String header;
  final String Function(Transaction) getValue;

  const CsvColumnConfig({
    required this.header,
    required this.getValue,
  });
}

/// PDF report configuration
class PdfReportConfig {
  final String title;
  final bool includeCoverPage;
  final bool includeCharts;
  final bool includeSummary;
  final bool includeTransactionList;
  final bool includeCategoryBreakdown;
  final bool includeAccountSummary;
  final String? customHeader;
  final String? customFooter;

  const PdfReportConfig({
    this.title = 'Financial Report',
    this.includeCoverPage = true,
    this.includeCharts = true,
    this.includeSummary = true,
    this.includeTransactionList = true,
    this.includeCategoryBreakdown = true,
    this.includeAccountSummary = true,
    this.customHeader,
    this.customFooter,
  });
}
