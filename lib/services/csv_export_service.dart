import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/transaction.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:intl/intl.dart';

/// CSV export templates
enum CsvTemplate {
  simple,
  detailed,
  taxPrep,
  custom;

  String get displayName {
    switch (this) {
      case CsvTemplate.simple:
        return 'Simple (Date, Type, Amount, Category)';
      case CsvTemplate.detailed:
        return 'Detailed (All Fields)';
      case CsvTemplate.taxPrep:
        return 'Tax Preparation (Categorized)';
      case CsvTemplate.custom:
        return 'Custom Columns';
    }
  }
}

/// Service for exporting data in CSV format
class CsvExportService {
  static const _csvSeparator = ',';
  static const _lineBreak = '\r\n';

  CsvExportService();

  /// Export transactions to CSV
  Future<ExportResult> export(
    ExportConfig config, {
    CsvTemplate template = CsvTemplate.detailed,
    List<String>? customColumns,
  }) async {
    final startTime = DateTime.now();

    try {
      // Get filtered transactions
      final transactions = await _getFilteredTransactions(config);
      final accounts = await _getAccountsMap();

      // Generate CSV content based on template
      final csvContent = _generateCsv(
        transactions,
        accounts,
        template,
        customColumns,
      );

      // Write to file
      final filePath = await _writeToFile(csvContent, config);
      final fileSize = await File(filePath).length();

      final duration = DateTime.now().difference(startTime);

      return ExportResult.success(
        filePath: filePath,
        fileSize: fileSize,
        format: ExportFormat.csv,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExportResult.failure(
        error: 'CSV export failed: ${e.toString()}',
        format: ExportFormat.csv,
        duration: duration,
      );
    }
  }

  /// Get filtered transactions
  Future<List<Transaction>> _getFilteredTransactions(ExportConfig config) async {
    var transactions = await AppDatabase.getTransactions();

    // Filter by date range
    if (config.startDate != null) {
      transactions = transactions.where((t) =>
          t.date.isAfter(config.startDate!) ||
          t.date.isAtSameMomentAs(config.startDate!)).toList();
    }

    if (config.endDate != null) {
      final endOfDay = DateTime(
        config.endDate!.year,
        config.endDate!.month,
        config.endDate!.day,
        23,
        59,
        59,
      );
      transactions = transactions.where((t) =>
          t.date.isBefore(endOfDay) ||
          t.date.isAtSameMomentAs(endOfDay)).toList();
    }

    // Filter by category
    if (config.categoryFilter != null && config.categoryFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) => config.categoryFilter!.contains(t.category))
          .toList();
    }

    // Filter by account
    if (config.accountFilter != null && config.accountFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) =>
              t.accountId != null && config.accountFilter!.contains(t.accountId))
          .toList();
    }

    // Filter deleted items
    if (!config.includeDeleted) {
      transactions = transactions.where((t) => t.deletedAt == null).toList();
    }

    // Sort by date (oldest first for CSV exports)
    transactions.sort((a, b) => a.date.compareTo(b.date));

    return transactions;
  }

  /// Get accounts as a map for quick lookup
  Future<Map<int, Account>> _getAccountsMap() async {
    final accounts = await AppDatabase.getAccounts();
    return {for (var acc in accounts) if (acc.id != null) acc.id!: acc};
  }

  /// Generate CSV content based on template
  String _generateCsv(
    List<Transaction> transactions,
    Map<int, Account> accounts,
    CsvTemplate template,
    List<String>? customColumns,
  ) {
    final buffer = StringBuffer();

    // Add header row
    buffer.write(_getHeaderRow(template, customColumns));
    buffer.write(_lineBreak);

    // Add data rows
    for (final transaction in transactions) {
      buffer.write(_getDataRow(transaction, accounts, template, customColumns));
      buffer.write(_lineBreak);
    }

    return buffer.toString();
  }

  /// Get CSV header row based on template
  String _getHeaderRow(CsvTemplate template, List<String>? customColumns) {
    List<String> headers;

    switch (template) {
      case CsvTemplate.simple:
        headers = ['Date', 'Type', 'Amount', 'Category'];
        break;

      case CsvTemplate.detailed:
        headers = [
          'Date',
          'Type',
          'Amount',
          'Category',
          'Account',
          'Note',
          'Transaction ID'
        ];
        break;

      case CsvTemplate.taxPrep:
        headers = [
          'Date',
          'Description',
          'Category',
          'Amount',
          'Type',
          'Account',
          'Tax Deductible'
        ];
        break;

      case CsvTemplate.custom:
        headers = customColumns ?? ['Date', 'Type', 'Amount', 'Category'];
        break;
    }

    return headers.map(_escapeValue).join(_csvSeparator);
  }

  /// Get CSV data row for a transaction
  String _getDataRow(
    Transaction transaction,
    Map<int, Account> accounts,
    CsvTemplate template,
    List<String>? customColumns,
  ) {
    List<String> values;

    final dateStr = _formatDate(transaction.date);
    final amountStr = _formatAmount(transaction.amount);
    final accountName = transaction.accountId != null
        ? (accounts[transaction.accountId]?.name ?? 'Unknown')
        : '';

    switch (template) {
      case CsvTemplate.simple:
        values = [
          dateStr,
          transaction.type,
          amountStr,
          transaction.category,
        ];
        break;

      case CsvTemplate.detailed:
        values = [
          dateStr,
          transaction.type,
          amountStr,
          transaction.category,
          accountName,
          transaction.note ?? '',
          transaction.id?.toString() ?? '',
        ];
        break;

      case CsvTemplate.taxPrep:
        final isTaxDeductible = _isTaxDeductible(transaction.category);
        values = [
          dateStr,
          transaction.note ?? transaction.category,
          transaction.category,
          amountStr,
          transaction.type,
          accountName,
          isTaxDeductible ? 'Yes' : 'No',
        ];
        break;

      case CsvTemplate.custom:
        // For custom template, use detailed as default
        values = [
          dateStr,
          transaction.type,
          amountStr,
          transaction.category,
          accountName,
          transaction.note ?? '',
        ];
        break;
    }

    return values.map(_escapeValue).join(_csvSeparator);
  }

  /// Format date for CSV
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format amount for CSV
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Check if category is tax deductible (simplified logic)
  bool _isTaxDeductible(String category) {
    const taxDeductibleCategories = {
      'Business',
      'Office',
      'Medical',
      'Charity',
      'Education',
      'Investment',
      'Home Office',
    };
    return taxDeductibleCategories.contains(category);
  }

  /// Escape CSV value (handle quotes, commas, newlines)
  String _escapeValue(String value) {
    // If value contains comma, quote, or newline, wrap in quotes
    if (value.contains(_csvSeparator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      // Escape existing quotes by doubling them
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Write CSV content to file
  Future<String> _writeToFile(String csvContent, ExportConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${directory.path}/exports');

    // Create exports directory if it doesn't exist
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    // Create file
    final fileName = config.getFileName();
    final file = File('${exportsDir.path}/$fileName');

    // Write data with UTF-8 encoding
    await file.writeAsString(csvContent, encoding: utf8);

    return file.path;
  }

  /// Export accounts to CSV
  Future<ExportResult> exportAccounts(ExportConfig config) async {
    final startTime = DateTime.now();

    try {
      final accounts = await AppDatabase.getAccounts();

      final buffer = StringBuffer();

      // Header
      buffer.write(_escapeValue('Account Name'));
      buffer.write(_csvSeparator);
      buffer.write(_escapeValue('Type'));
      buffer.write(_csvSeparator);
      buffer.write(_escapeValue('Balance'));
      buffer.write(_csvSeparator);
      buffer.write(_escapeValue('Last 4 Digits'));
      buffer.write(_csvSeparator);
      buffer.write(_escapeValue('Due Date'));
      buffer.write(_csvSeparator);
      buffer.write(_escapeValue('Credit Limit'));
      buffer.write(_lineBreak);

      // Data rows
      for (final account in accounts) {
        buffer.write(_escapeValue(account.name));
        buffer.write(_csvSeparator);
        buffer.write(_escapeValue(account.type));
        buffer.write(_csvSeparator);
        buffer.write(_formatAmount(account.balance));
        buffer.write(_csvSeparator);
        buffer.write(_escapeValue(account.last4 ?? ''));
        buffer.write(_csvSeparator);
        buffer.write(account.dueDateDay?.toString() ?? '');
        buffer.write(_csvSeparator);
        buffer.write(account.creditLimit?.toStringAsFixed(2) ?? '');
        buffer.write(_lineBreak);
      }

      final filePath = await _writeToFile(buffer.toString(), config);
      final fileSize = await File(filePath).length();

      final duration = DateTime.now().difference(startTime);

      return ExportResult.success(
        filePath: filePath,
        fileSize: fileSize,
        format: ExportFormat.csv,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExportResult.failure(
        error: 'Account export failed: ${e.toString()}',
        format: ExportFormat.csv,
        duration: duration,
      );
    }
  }

  /// Get preview of CSV export
  Future<String> getPreview(
    ExportConfig config, {
    CsvTemplate template = CsvTemplate.detailed,
    int maxRows = 5,
  }) async {
    final transactions = await _getFilteredTransactions(config);
    final accounts = await _getAccountsMap();

    final previewTransactions = transactions.take(maxRows).toList();

    return _generateCsv(
      previewTransactions,
      accounts,
      template,
      null,
    );
  }
}
