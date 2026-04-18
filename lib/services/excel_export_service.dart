import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/budget.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/transaction.dart';

/// Service for exporting data in Excel format
class ExcelExportService {
  ExcelExportService();

  /// Export data to Excel workbook
  Future<ExportResult> export(ExportConfig config) async {
    final startTime = DateTime.now();

    try {
      // Create Excel workbook
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Add sheets based on config
      if (config.dataTypes.contains(ExportDataType.transactions)) {
        await _addTransactionsSheet(excel, config);
      }

      if (config.dataTypes.contains(ExportDataType.accounts)) {
        await _addAccountsSheet(excel);
      }

      if (config.dataTypes.contains(ExportDataType.budgets)) {
        await _addBudgetsSheet(excel);
      }

      if (config.dataTypes.contains(ExportDataType.savingsGoals)) {
        await _addSavingsGoalsSheet(excel);
      }

      // Add summary sheet if multiple data types
      if (config.dataTypes.length > 1 && config.includeMetadata) {
        await _addSummarySheet(excel, config);
      }

      // Save to file
      final filePath = await _saveExcelFile(excel, config);
      final fileSize = await File(filePath).length();

      final duration = DateTime.now().difference(startTime);

      return ExportResult.success(
        filePath: filePath,
        fileSize: fileSize,
        format: ExportFormat.excel,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExportResult.failure(
        error: 'Excel export failed: ${e.toString()}',
        format: ExportFormat.excel,
        duration: duration,
      );
    }
  }

  /// Add transactions sheet to workbook
  Future<void> _addTransactionsSheet(Excel excel, ExportConfig config) async {
    final sheet = excel['Transactions'];

    // Get filtered transactions
    final transactions = await _getFilteredTransactions(config);
    final accounts = await _getAccountsMap();

    // Add header with styling
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
    );

    final headers = ['Date', 'Type', 'Amount', 'Category', 'Account', 'Note'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Add data rows
    var rowIndex = 1;
    for (final transaction in transactions) {
      final accountName = transaction.accountId != null
          ? (accounts[transaction.accountId]?.name ?? 'Unknown')
          : '';

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(_formatDate(transaction.date));

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(transaction.type);

      final amountCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      amountCell.value = DoubleCellValue(transaction.amount);
      amountCell.cellStyle = CellStyle(
        numberFormat: NumFormat.standard_2,
      );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(transaction.category);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(accountName);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(transaction.note ?? '');

      rowIndex++;
    }

    // Auto-fit columns (approximate)
    sheet.setColumnWidth(0, 12); // Date
    sheet.setColumnWidth(1, 10); // Type
    sheet.setColumnWidth(2, 12); // Amount
    sheet.setColumnWidth(3, 15); // Category
    sheet.setColumnWidth(4, 15); // Account
    sheet.setColumnWidth(5, 30); // Note
  }

  /// Add accounts sheet to workbook
  Future<void> _addAccountsSheet(Excel excel) async {
    final sheet = excel['Accounts'];
    final accounts = await AppDatabase.getAccounts();

    // Header
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
      bold: true,
    );

    final headers = ['Name', 'Type', 'Balance', 'Last 4', 'Due Date', 'Credit Limit'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data
    var rowIndex = 1;
    for (final account in accounts) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(account.name);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(account.type);

      final balanceCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      balanceCell.value = DoubleCellValue(account.balance);
      balanceCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(account.last4 ?? '');

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = account.dueDateDay != null ? IntCellValue(account.dueDateDay!) : TextCellValue('');

      final creditCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      if (account.creditLimit != null) {
        creditCell.value = DoubleCellValue(account.creditLimit!);
        creditCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);
      }

      rowIndex++;
    }

    // Column widths
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 10);
    sheet.setColumnWidth(4, 10);
    sheet.setColumnWidth(5, 12);
  }

  /// Add budgets sheet to workbook
  Future<void> _addBudgetsSheet(Excel excel) async {
    final sheet = excel['Budgets'];
    final budgets = await _getAllBudgets();
    
    // Get spent amounts by category for each month/year
    final transactions = await AppDatabase.getTransactions();
    final spentMap = <String, double>{}; // key: "year-month-category"
    
    for (final t in transactions) {
      if (t.type == 'expense') {
        final key = '${t.date.year}-${t.date.month}-${t.category}';
        spentMap[key] = (spentMap[key] ?? 0) + t.amount;
      }
    }

    // Header
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.orange,
      fontColorHex: ExcelColor.white,
      bold: true,
    );

    final headers = ['Month', 'Year', 'Category', 'Limit', 'Spent', 'Remaining'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data
    var rowIndex = 1;
    for (final budget in budgets) {
      final spentKey = '${budget.year}-${budget.month}-${budget.category}';
      final spent = spentMap[spentKey] ?? 0.0;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = IntCellValue(budget.month);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(budget.year);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(budget.category);

      final limitCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      limitCell.value = DoubleCellValue(budget.limit);
      limitCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      final spentCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      spentCell.value = DoubleCellValue(spent);
      spentCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      final remaining = budget.limit - spent;
      final remainingCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      remainingCell.value = DoubleCellValue(remaining);
      remainingCell.cellStyle = CellStyle(
        numberFormat: NumFormat.standard_2,
        fontColorHex: remaining >= 0 ? ExcelColor.green : ExcelColor.red,
      );

      rowIndex++;
    }

    // Column widths
    for (var i = 0; i < 6; i++) {
      sheet.setColumnWidth(i, 12);
    }
  }

  /// Add savings goals sheet to workbook
  Future<void> _addSavingsGoalsSheet(Excel excel) async {
    final sheet = excel['Savings Goals'];
    final goals = await AppDatabase.getGoals();

    // Header
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.purple,
      fontColorHex: ExcelColor.white,
      bold: true,
    );

    final headers = ['Name', 'Target', 'Saved', 'Remaining', 'Progress %', 'Priority'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data
    var rowIndex = 1;
    for (final goal in goals) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(goal.name);

      final targetCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      targetCell.value = DoubleCellValue(goal.target);
      targetCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      final savedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      savedCell.value = DoubleCellValue(goal.saved);
      savedCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      final remaining = goal.target - goal.saved;
      final remainingCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      remainingCell.value = DoubleCellValue(remaining);
      remainingCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      final progress = goal.target > 0 ? (goal.saved / goal.target * 100) : 0.0;
      final progressCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      progressCell.value = DoubleCellValue(progress.toDouble());
      progressCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = IntCellValue(goal.priority);

      rowIndex++;
    }

    // Column widths
    sheet.setColumnWidth(0, 20);
    for (var i = 1; i < 6; i++) {
      sheet.setColumnWidth(i, 12);
    }
  }

  /// Add summary sheet to workbook
  Future<void> _addSummarySheet(Excel excel, ExportConfig config) async {
    final sheet = excel['Summary'];

    var rowIndex = 0;

    // Title
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = TextCellValue('PocketFlow Export Summary');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16);
    rowIndex += 2;

    // Export date
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        .value = TextCellValue('Export Date:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        .value = TextCellValue(_formatDate(DateTime.now()));
    rowIndex++;

    // Date range
    if (config.startDate != null && config.endDate != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('Date Range:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue('${_formatDate(config.startDate!)} to ${_formatDate(config.endDate!)}');
      rowIndex++;
    }

    rowIndex++;

    // Statistics
    if (config.dataTypes.contains(ExportDataType.transactions)) {
      final transactions = await _getFilteredTransactions(config);
      
      double totalIncome = 0;
      double totalExpense = 0;
      for (final t in transactions) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
        }
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('Total Transactions:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = IntCellValue(transactions.length);
      rowIndex++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('Total Income:');
      final incomeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      incomeCell.value = DoubleCellValue(totalIncome);
      incomeCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2, fontColorHex: ExcelColor.green);
      rowIndex++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('Total Expense:');
      final expenseCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      expenseCell.value = DoubleCellValue(totalExpense);
      expenseCell.cellStyle = CellStyle(numberFormat: NumFormat.standard_2, fontColorHex: ExcelColor.red);
      rowIndex++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue('Net Amount:');
      final netCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      final netAmount = totalIncome - totalExpense;
      netCell.value = DoubleCellValue(netAmount);
      netCell.cellStyle = CellStyle(
        numberFormat: NumFormat.standard_2,
        fontColorHex: netAmount >= 0 ? ExcelColor.green : ExcelColor.red,
        bold: true,
      );
    }

    // Column widths
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 15);
  }

  /// Save Excel file
  Future<String> _saveExcelFile(Excel excel, ExportConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${directory.path}/exports');

    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final fileName = config.getFileName();
    final file = File('${exportsDir.path}/$fileName');

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file.path;
  }

  /// Get filtered transactions (same as JSON/CSV services)
  Future<List<Transaction>> _getFilteredTransactions(ExportConfig config) async {
    var transactions = await AppDatabase.getTransactions();

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
        23, 59, 59,
      );
      transactions = transactions.where((t) =>
          t.date.isBefore(endOfDay) || t.date.isAtSameMomentAs(endOfDay)).toList();
    }

    if (config.categoryFilter != null && config.categoryFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) => config.categoryFilter!.contains(t.category))
          .toList();
    }

    if (config.accountFilter != null && config.accountFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) => t.accountId != null && config.accountFilter!.contains(t.accountId))
          .toList();
    }

    if (!config.includeDeleted) {
      transactions = transactions.where((t) => t.deletedAt == null).toList();
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));

    return transactions;
  }

  /// Get accounts as map
  Future<Map<int, Account>> _getAccountsMap() async {
    final accounts = await AppDatabase.getAccounts();
    return {for (final acc in accounts) if (acc.id != null) acc.id!: acc};
  }

  /// Get all budgets
  Future<List<Budget>> _getAllBudgets() async {
    final now = DateTime.now();
    final allBudgets = <Budget>[];

    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final budgets = await AppDatabase.getBudgets(date.month, date.year);
      allBudgets.addAll(budgets);
    }

    return allBudgets;
  }

  /// Format date
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
