import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/budget.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/recurring_transaction.dart';
import 'package:pocket_flow/models/savings_goal.dart';
import 'package:pocket_flow/models/transaction.dart';

/// Service for exporting data in JSON format
class JsonExportService {
  JsonExportService();

  /// Export data based on configuration
  Future<ExportResult> export(ExportConfig config) async {
    final startTime = DateTime.now();
    
    try {
      // Gather data based on config
      final exportData = await _gatherExportData(config);
      
      // Convert to JSON
      final jsonString = _formatJson(exportData, config);
      
      // Write to file
      final filePath = await _writeToFile(jsonString, config);
      final fileSize = await File(filePath).length();
      
      final duration = DateTime.now().difference(startTime);
      
      return ExportResult.success(
        filePath: filePath,
        fileSize: fileSize,
        format: ExportFormat.json,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExportResult.failure(
        error: 'Export failed: ${e.toString()}',
        format: ExportFormat.json,
        duration: duration,
      );
    }
  }

  /// Gather all data for export based on configuration
  Future<ExportData> _gatherExportData(ExportConfig config) async {
    final transactions = config.dataTypes.contains(ExportDataType.transactions)
        ? await _getFilteredTransactions(config)
        : <Transaction>[];
    
    final accounts = config.dataTypes.contains(ExportDataType.accounts)
        ? await AppDatabase.getAccounts()
        : <Account>[];
    
    final budgets = config.dataTypes.contains(ExportDataType.budgets)
        ? await _getAllBudgets()
        : <Budget>[];
    
    final savingsGoals = config.dataTypes.contains(ExportDataType.savingsGoals)
        ? await AppDatabase.getGoals()
        : <SavingsGoal>[];
    
    final recurringTransactions = config.dataTypes.contains(ExportDataType.recurringTransactions)
        ? await AppDatabase.getRecurring()
        : <RecurringTransaction>[];
    
    // Calculate metadata
    final metadata = await _generateMetadata(
      transactions: transactions,
      accounts: accounts,
      budgets: budgets,
      savingsGoals: savingsGoals,
      recurringTransactions: recurringTransactions,
      config: config,
    );
    
    return ExportData(
      transactions: transactions,
      accounts: accounts,
      budgets: budgets,
      savingsGoals: savingsGoals,
      recurringTransactions: recurringTransactions,
      metadata: metadata,
    );
  }

  /// Get filtered transactions based on config
  Future<List<Transaction>> _getFilteredTransactions(ExportConfig config) async {
    var transactions = await AppDatabase.getTransactions();
    
    // Filter by date range
    if (config.startDate != null) {
      transactions = transactions.where((t) => 
        t.date.isAfter(config.startDate!) || t.date.isAtSameMomentAs(config.startDate!)
      ).toList();
    }
    
    if (config.endDate != null) {
      final endOfDay = DateTime(
        config.endDate!.year,
        config.endDate!.month,
        config.endDate!.day,
        23, 59, 59,
      );
      transactions = transactions.where((t) => 
        t.date.isBefore(endOfDay) || t.date.isAtSameMomentAs(endOfDay)
      ).toList();
    }
    
    // Filter by category
    if (config.categoryFilter != null && config.categoryFilter!.isNotEmpty) {
      transactions = transactions.where((t) => 
        config.categoryFilter!.contains(t.category)
      ).toList();
    }
    
    // Filter by account
    if (config.accountFilter != null && config.accountFilter!.isNotEmpty) {
      transactions = transactions.where((t) => 
        t.accountId != null && config.accountFilter!.contains(t.accountId)
      ).toList();
    }
    
    // Filter deleted items
    if (!config.includeDeleted) {
      transactions = transactions.where((t) => t.deletedAt == null).toList();
    }
    
    return transactions;
  }

  /// Get all budgets across all months
  Future<List<Budget>> _getAllBudgets() async {
    final now = DateTime.now();
    final allBudgets = <Budget>[];
    
    // Get budgets for last 12 months
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i);
      final budgets = await AppDatabase.getBudgets(date.month, date.year);
      allBudgets.addAll(budgets);
    }
    
    return allBudgets;
  }

  /// Generate export metadata
  Future<ExportMetadata> _generateMetadata({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<SavingsGoal> savingsGoals,
    required List<RecurringTransaction> recurringTransactions,
    required ExportConfig config,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    
    // Calculate income/expense totals
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final transaction in transactions) {
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }
    
    // Get unique categories
    final categories = transactions
        .map((t) => t.category)
        .toSet()
        .toList();
    
    // Get unique account IDs
    final accountIds = transactions
        .where((t) => t.accountId != null)
        .map((t) => t.accountId!)
        .toSet()
        .toList();
    
    return ExportMetadata(
      appVersion: packageInfo.version,
      exportDate: DateTime.now(),
      dateRangeStart: config.startDate,
      dateRangeEnd: config.endDate,
      transactionCount: transactions.length,
      accountCount: accounts.length,
      budgetCount: budgets.length,
      savingsGoalCount: savingsGoals.length,
      recurringTransactionCount: recurringTransactions.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netAmount: totalIncome - totalExpense,
      includedCategories: categories,
      includedAccounts: accountIds,
    );
  }

  /// Format data as JSON string
  String _formatJson(ExportData data, ExportConfig config) {
    final map = data.toJson();
    
    // Remove metadata if not requested
    if (!config.includeMetadata) {
      map.remove('metadata');
    }
    
    // Pretty print for readability
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  /// Write JSON string to file
  Future<String> _writeToFile(String jsonString, ExportConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${directory.path}/exports');
    
    // Create exports directory if it doesn't exist
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    
    // Create file
    final fileName = config.getFileName();
    final file = File('${exportsDir.path}/$fileName');
    
    // Write data
    await file.writeAsString(jsonString);
    
    return file.path;
  }

  /// Get preview of export data (for UI display before confirming export)
  Future<ExportPreview> getPreview(ExportConfig config) async {
    final exportData = await _gatherExportData(config);
    
    return ExportPreview(
      totalTransactions: exportData.transactions.length,
      totalAccounts: exportData.accounts.length,
      totalBudgets: exportData.budgets.length,
      totalSavingsGoals: exportData.savingsGoals.length,
      totalRecurringTransactions: exportData.recurringTransactions.length,
      estimatedFileSize: _estimateFileSize(exportData),
      dateRange: config.startDate != null && config.endDate != null
          ? '${_formatDate(config.startDate!)} - ${_formatDate(config.endDate!)}'
          : 'All time',
    );
  }

  /// Estimate file size based on data
  int _estimateFileSize(ExportData data) {
    // Rough estimate: ~200 bytes per transaction, ~100 per account, etc.
    return (data.transactions.length * 200) +
           (data.accounts.length * 100) +
           (data.budgets.length * 100) +
           (data.savingsGoals.length * 100) +
           (data.recurringTransactions.length * 150);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Preview information for export
class ExportPreview {

  const ExportPreview({
    required this.totalTransactions,
    required this.totalAccounts,
    required this.totalBudgets,
    required this.totalSavingsGoals,
    required this.totalRecurringTransactions,
    required this.estimatedFileSize,
    required this.dateRange,
  });
  final int totalTransactions;
  final int totalAccounts;
  final int totalBudgets;
  final int totalSavingsGoals;
  final int totalRecurringTransactions;
  final int estimatedFileSize;
  final String dateRange;

  int get totalItems =>
      totalTransactions +
      totalAccounts +
      totalBudgets +
      totalSavingsGoals +
      totalRecurringTransactions;

  String get fileSizeFormatted {
    if (estimatedFileSize < 1024) {
      return '$estimatedFileSize B';
    } else if (estimatedFileSize < 1024 * 1024) {
      return '${(estimatedFileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(estimatedFileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
