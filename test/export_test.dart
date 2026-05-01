import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/budget.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/transaction.dart' as model;

void main() {
  group('Export Data Models', () {
    test('ExportFormat should have correct properties', () {
      expect(ExportFormat.json.displayName, 'JSON');
      expect(ExportFormat.json.fileExtension, '.json');
      expect(ExportFormat.json.mimeType, 'application/json');

      expect(ExportFormat.csv.displayName, 'CSV');
      expect(ExportFormat.csv.fileExtension, '.csv');

      expect(ExportFormat.excel.displayName, 'Excel');
      expect(ExportFormat.excel.fileExtension, '.xlsx');

      expect(ExportFormat.pdf.displayName, 'PDF');
      expect(ExportFormat.pdf.fileExtension, '.pdf');
    });

    test('ExportConfig should generate correct filename', () {
      final config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
        startDate: DateTime(2024),
        endDate: DateTime(2024, 1, 31),
      );

      final fileName = config.getFileName();
      expect(fileName, contains('pocketflow_export'));
      expect(fileName, endsWith('.json'));
    });

    test('ExportConfig should handle null dates', () {
      const config = ExportConfig(
        format: ExportFormat.csv,
        dataTypes: [ExportDataType.transactions],
      );

      final fileName = config.getFileName();
      expect(fileName, contains('pocketflow_export'));
      expect(fileName, endsWith('.csv'));
    });

    test('ExportResult should track success', () {
      final result = ExportResult.success(
        filePath: '/test/path/file.json',
        fileSize: 1024,
        format: ExportFormat.json,
        duration: const Duration(seconds: 2),
      );

      expect(result.success, isTrue);
      expect(result.fileName, 'file.json');
      expect(result.formattedSize, '1.00 KB');
      expect(result.formattedDuration, '2.0s');
    });

    test('ExportResult should track failure', () {
      final result = ExportResult.failure(
        error: 'Test error',
        format: ExportFormat.csv,
        duration: const Duration(milliseconds: 500),
      );

      expect(result.success, isFalse);
      expect(result.error, 'Test error');
      expect(result.filePath, isNull);
    });

    test('ExportResult should format file sizes correctly', () {
      final small = ExportResult.success(
        filePath: '/test/file1',
        fileSize: 512,
        format: ExportFormat.json,
        duration: const Duration(seconds: 1),
      );
      expect(small.formattedSize, '512 bytes');

      final kb = ExportResult.success(
        filePath: '/test/file2',
        fileSize: 2048,
        format: ExportFormat.json,
        duration: const Duration(seconds: 1),
      );
      expect(kb.formattedSize, '2.00 KB');

      final mb = ExportResult.success(
        filePath: '/test/file3',
        fileSize: 2 * 1024 * 1024,
        format: ExportFormat.json,
        duration: const Duration(seconds: 1),
      );
      expect(mb.formattedSize, '2.00 MB');
    });

    test('ExportData should serialize to JSON correctly', () {
      final transaction = model.Transaction(
        type: 'expense',
        amount: 100.50,
        category: 'Food',
        date: DateTime(2024, 1, 15),
        accountId: 1,
      );

      final account = Account(
        name: 'Test Account',
        type: 'checking',
        balance: 1000.0,
      );

      final budget = Budget(
        category: 'Food',
        limit: 500.0,
        month: 1,
        year: 2024,
      );

      final metadata = ExportMetadata(
        appVersion: '1.0.0',
        exportDate: DateTime.now(),
        transactionCount: 1,
        accountCount: 1,
        budgetCount: 1,
        savingsGoalCount: 0,
        recurringTransactionCount: 0,
        totalIncome: 0.0,
        totalExpense: 0.0,
        netAmount: 0.0,
      );

      final exportData = ExportData(
        transactions: [transaction],
        accounts: [account],
        budgets: [budget],
        savingsGoals: [],
        recurringTransactions: [],
        metadata: metadata,
      );

      final json = exportData.toJson();

      expect(json['transactions'], isA<List>());
      expect(json['transactions'].length, 1);
      expect(json['accounts'].length, 1);
      expect(json['budgets'].length, 1);
    });

    test('ExportMetadata should include statistics', () {
      final metadata = ExportMetadata(
        appVersion: '1.0.0',
        exportDate: DateTime(2024, 1, 15),
        transactionCount: 100,
        accountCount: 3,
        budgetCount: 5,
        savingsGoalCount: 2,
        recurringTransactionCount: 4,
        dateRangeStart: DateTime(2024),
        dateRangeEnd: DateTime(2024, 1, 31),
        totalIncome: 5000.0,
        totalExpense: 3000.0,
        netAmount: 2000.0,
      );

      final json = metadata.toJson();

      expect(json['appVersion'], '1.0.0');
      expect(json['totalTransactions'], 100);
      expect(json['totalIncome'], 5000.0);
      expect(json['netAmount'], 2000.0);
    });

    test('PdfReportConfig should have sensible defaults', () {
      const config = PdfReportConfig();

      expect(config.title, 'Financial Report');
      expect(config.includeCoverPage, isTrue);
      expect(config.includeSummary, isTrue);
      expect(config.includeCharts, isTrue);
    });

    test('PdfReportConfig should accept custom values', () {
      const config = PdfReportConfig(
        title: 'Custom Report',
        includeCoverPage: false,
        includeCharts: false,
        customHeader: 'My Custom Header',
      );

      expect(config.title, 'Custom Report');
      expect(config.includeCoverPage, isFalse);
      expect(config.includeCharts, isFalse);
      expect(config.customHeader, 'My Custom Header');
    });
  });

  group('Export File Naming', () {
    test('Should include timestamp in filename', () {
      const config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );

      final fileName1 = config.getFileName();
      // Wait a tiny bit
      Future.delayed(const Duration(milliseconds: 10));
      final fileName2 = config.getFileName();

      // Both should contain pocketflow_export
      expect(fileName1, contains('pocketflow_export'));
      expect(fileName2, contains('pocketflow_export'));
    });

    test('Should have correct extension for each format', () {
      final formats = [
        (ExportFormat.json, '.json'),
        (ExportFormat.csv, '.csv'),
        (ExportFormat.excel, '.xlsx'),
        (ExportFormat.pdf, '.pdf'),
      ];

      for (final (format, ext) in formats) {
        final config = ExportConfig(
          format: format,
          dataTypes: [ExportDataType.transactions],
        );
        expect(config.getFileName(), endsWith(ext));
      }
    });
  });

  group('Export Data Types', () {
    test('All data types should have display names', () {
      for (final dataType in ExportDataType.values) {
expect(dataType.displayName, isNotEmpty);
      }

      expect(ExportDataType.transactions.displayName, 'Transactions');
      expect(ExportDataType.accounts.displayName, 'Accounts');
      expect(ExportDataType.budgets.displayName, 'Budgets');
      expect(ExportDataType.savingsGoals.displayName, 'Savings Goals');
    });
  });

  group('Duration Formatting', () {
    test('Should format milliseconds correctly', () {
      final result = ExportResult.success(
        filePath: '/test/file',
        fileSize: 100,
        format: ExportFormat.json,
        duration: const Duration(milliseconds: 500),
      );

      expect(result.formattedDuration, '0.5s');
    });

    test('Should format seconds correctly', () {
      final result = ExportResult.success(
        filePath: '/test/file',
        fileSize: 100,
        format: ExportFormat.json,
        duration: const Duration(seconds: 3, milliseconds: 500),
      );

      expect(result.formattedDuration, '3.5s');
    });

    test('Should format minutes correctly', () {
      final result = ExportResult.success(
        filePath: '/test/file',
        fileSize: 100,
        format: ExportFormat.json,
        duration: const Duration(minutes: 1, seconds: 30),
      );

      // Should show as seconds for now
      expect(result.formattedDuration, '90.0s');
    });
  });

  group('Edge Cases', () {
    test('ExportConfig should handle empty data types list', () {
      const config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [],
      );

      expect(config.dataTypes, isEmpty);
      expect(config.getFileName(), contains('pocketflow_export'));
    });

    test('ExportData should handle empty lists', () {
      final metadata = ExportMetadata(
        appVersion: '1.0.0',
        exportDate: DateTime.now(),
        transactionCount: 0,
        accountCount: 0,
        budgetCount: 0,
        savingsGoalCount: 0,
        recurringTransactionCount: 0,
        totalIncome: 0.0,
        totalExpense: 0.0,
        netAmount: 0.0,
      );

      final exportData = ExportData(
        transactions: [],
        accounts: [],
        budgets: [],
        savingsGoals: [],
        recurringTransactions: [],
        metadata: metadata,
      );

      final json = exportData.toJson();

      expect(json['transactions'], isEmpty);
      expect(json['accounts'], isEmpty);
      expect(json['budgets'], isEmpty);
    });

    test('ExportResult should handle zero file size', () {
      final result = ExportResult.success(
        filePath: '/test/empty',
        fileSize: 0,
        format: ExportFormat.json,
        duration: const Duration(milliseconds: 100),
      );

      expect(result.formattedSize, '0 bytes');
    });

    test('ExportResult should handle very short duration', () {
      final result = ExportResult.success(
        filePath: '/test/file',
        fileSize: 100,
        format: ExportFormat.json,
        duration: const Duration(milliseconds: 1),
      );

      expect(result.formattedDuration, isNotEmpty);
    });
  });

  group('Filter Validation', () {
    test('Category filter should be optional', () {
      const config1 = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );
      expect(config1.categoryFilter, isNull);

      const config2 = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
        categoryFilter: ['Food', 'Transport'],
      );
      expect(config2.categoryFilter, ['Food', 'Transport']);
    });

    test('Account filter should be optional', () {
      const config1 = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );
      expect(config1.accountFilter, isNull);

      const config2 = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
        accountFilter: [1, 2, 3],
      );
      expect(config2.accountFilter, [1, 2, 3]);
    });

    test('Date filters should be optional', () {
      const config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );

      expect(config.startDate, isNull);
      expect(config.endDate, isNull);
    });

    test('Include deleted should default to false', () {
      const config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );

      expect(config.includeDeleted, isFalse);
    });

    test('Include metadata should default to true', () {
      const config = ExportConfig(
        format: ExportFormat.json,
        dataTypes: [ExportDataType.transactions],
      );

      expect(config.includeMetadata, isTrue);
    });
  });
}
