
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/account.dart';
import 'package:pocket_flow/models/budget.dart';
import 'package:pocket_flow/models/export_models.dart';
import 'package:pocket_flow/models/transaction.dart';

// Compute saved amount for a goal (replace with actual logic as needed)
double _getSavedForGoal(goal) {
  // TODO: Replace with real computation from transactions if needed
  return goal.saved ?? 0.0;
}

/// Service for exporting data in PDF format
class PdfExportService {
  PdfExportService();

  /// Export data to PDF report
  Future<ExportResult> export(
    ExportConfig config,
    PdfReportConfig reportConfig,
  ) async {
    final startTime = DateTime.now();

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add cover page if enabled
      if (reportConfig.includeCoverPage) {
        pdf.addPage(_buildCoverPage(config, reportConfig));
      }

      // Add summary page
      if (reportConfig.includeSummary) {
        pdf.addPage(await _buildSummaryPage(config, reportConfig));
      }

      // Add transactions if included
      if (config.dataTypes.contains(ExportDataType.transactions)) {
        final transactionPages = await _buildTransactionPages(config, reportConfig);
        for (final page in transactionPages) {
          pdf.addPage(page);
        }
      }

      // Add accounts if included
      if (config.dataTypes.contains(ExportDataType.accounts)) {
        pdf.addPage(await _buildAccountsPage());
      }

      // Add budgets if included
      if (config.dataTypes.contains(ExportDataType.budgets)) {
        pdf.addPage(await _buildBudgetsPage());
      }

      // Add goals if included
      if (config.dataTypes.contains(ExportDataType.goals)) {
        pdf.addPage(await _buildSavingsGoalsPage());
      }
  // Compute saved amount for a goal (replace with actual logic as needed)
  double _getSavedForGoal(goal) {
    // TODO: Replace with real computation from transactions if needed
    return goal.saved ?? 0.0;
  }

      // Save to file
      final filePath = await _savePdfFile(pdf, config);
      final fileSize = await File(filePath).length();

      final duration = DateTime.now().difference(startTime);

      return ExportResult.success(
        filePath: filePath,
        fileSize: fileSize,
        format: ExportFormat.pdf,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExportResult.failure(
        error: 'PDF export failed: ${e.toString()}',
        format: ExportFormat.pdf,
        duration: duration,
      );
    }
  }

  /// Build cover page
  pw.Page _buildCoverPage(ExportConfig config, PdfReportConfig reportConfig) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              reportConfig.title,
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'PocketFlow Financial Report',
              style: const pw.TextStyle(
                fontSize: 20,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 40),
            if (config.startDate != null && config.endDate != null) ...[
              pw.Text(
                'Period: ${_formatDate(config.startDate!)} to ${_formatDate(config.endDate!)}',
                style: const pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
            pw.Text(
              'Generated: ${_formatDate(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build summary page
  Future<pw.Page> _buildSummaryPage(
    ExportConfig config,
    PdfReportConfig reportConfig,
  ) async {
    final transactions = await _getFilteredTransactions(config);

    double totalIncome = 0;
    double totalExpense = 0;
    final categoryExpenses = <String, double>{};

    for (final t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        categoryExpenses[t.category] = (categoryExpenses[t.category] ?? 0) + t.amount;
      }
    }

    final netAmount = totalIncome - totalExpense;

    // Sort categories by spending
    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader('Financial Summary'),
          pw.SizedBox(height: 20),

          // Period information
          if (config.startDate != null && config.endDate != null) ...[
            pw.Text(
              'Report Period: ${_formatDate(config.startDate!)} to ${_formatDate(config.endDate!)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
          ],

          // Summary statistics
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                _buildSummaryRow('Total Transactions', transactions.length.toString()),
                pw.Divider(),
                _buildSummaryRow(
                  'Total Income',
                  _formatCurrency(totalIncome),
                  valueColor: PdfColors.green700,
                ),
                _buildSummaryRow(
                  'Total Expenses',
                  _formatCurrency(totalExpense),
                  valueColor: PdfColors.red700,
                ),
                pw.Divider(thickness: 2),
                _buildSummaryRow(
                  'Net Amount',
                  _formatCurrency(netAmount),
                  valueColor: netAmount >= 0 ? PdfColors.green700 : PdfColors.red700,
                  bold: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Top spending categories
          if (topCategories.isNotEmpty) ...[
            pw.Text(
              'Top Spending Categories',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: topCategories.map((entry) {
                  final percentage = totalExpense > 0
                      ? (entry.value / totalExpense * 100)
                      : 0.0;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(entry.key),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _formatCurrency(entry.value),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const pw.TextStyle(color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Custom header if provided
          if (reportConfig.customHeader != null) ...[
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Text(reportConfig.customHeader!),
          ],
        ],
      ),
    );
  }

  /// Build transaction pages (multiple pages if needed)
  Future<List<pw.Page>> _buildTransactionPages(
    ExportConfig config,
    PdfReportConfig reportConfig,
  ) async {
    final transactions = await _getFilteredTransactions(config);
    final accounts = await _getAccountsMap();
    final pages = <pw.Page>[];

    // Split transactions into pages (20 per page)
    const transactionsPerPage = 20;
    for (var i = 0; i < transactions.length; i += transactionsPerPage) {
      final pageTransactions = transactions.skip(i).take(transactionsPerPage).toList();
      final pageNumber = (i ~/ transactionsPerPage) + 1;
      final totalPages = (transactions.length / transactionsPerPage).ceil();

      pages.add(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('Transactions (Page $pageNumber of $totalPages)'),
              pw.SizedBox(height: 20),
              _buildTransactionTable(pageTransactions, accounts),
            ],
          ),
        ),
      );
    }

    return pages.isEmpty
        ? [
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader('Transactions'),
                  pw.SizedBox(height: 20),
                  pw.Text('No transactions found for the selected period.'),
                ],
              ),
            )
          ]
        : pages;
  }

  /// Build transaction table
  pw.Widget _buildTransactionTable(
    List<Transaction> transactions,
    Map<int, Account> accounts,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // Date
        1: const pw.FlexColumnWidth(), // Type
        2: const pw.FlexColumnWidth(1.5), // Amount
        3: const pw.FlexColumnWidth(2), // Category
        4: const pw.FlexColumnWidth(2), // Account
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            _buildTableCell('Date', bold: true),
            _buildTableCell('Type', bold: true),
            _buildTableCell('Amount', bold: true),
            _buildTableCell('Category', bold: true),
            _buildTableCell('Account', bold: true),
          ],
        ),
        // Data rows
        ...transactions.map((t) {
          final accountName = t.accountId != null
              ? (accounts[t.accountId]?.name ?? 'Unknown')
              : '';
          return pw.TableRow(
            children: [
              _buildTableCell(_formatDate(t.date)),
              _buildTableCell(t.type == 'income' ? 'Inc' : 'Exp'),
              _buildTableCell(
                _formatCurrency(t.amount),
                color: t.type == 'income' ? PdfColors.green700 : PdfColors.red700,
              ),
              _buildTableCell(t.category),
              _buildTableCell(accountName),
            ],
          );
        }),
      ],
    );
  }

  /// Build accounts page
  Future<pw.Page> _buildAccountsPage() async {
    final accounts = await AppDatabase.getAccounts();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader('Accounts Summary'),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Name
              1: const pw.FlexColumnWidth(1.5), // Type
              2: const pw.FlexColumnWidth(1.5), // Balance
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Account Name', bold: true),
                  _buildTableCell('Type', bold: true),
                  _buildTableCell('Balance', bold: true),
                ],
              ),
              // Data
              ...accounts.map((account) => pw.TableRow(
                    children: [
                      _buildTableCell(account.name),
                      _buildTableCell(account.type),
                      _buildTableCell(
                        _formatCurrency(account.balance),
                        color: account.balance >= 0
                            ? PdfColors.green700
                            : PdfColors.red700,
                      ),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  /// Build budgets page
  Future<pw.Page> _buildBudgetsPage() async {
    final budgets = await _getAllBudgets();
    final transactions = await AppDatabase.getTransactions();

    // Calculate spent amounts
    final spentMap = <String, double>{};
    for (final t in transactions) {
      if (t.type == 'expense') {
        final key = '${t.date.year}-${t.date.month}-${t.category}';
        spentMap[key] = (spentMap[key] ?? 0) + t.amount;
      }
    }

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader('Budget Overview'),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(), // Month
              1: const pw.FlexColumnWidth(2), // Category
              2: const pw.FlexColumnWidth(1.5), // Limit
              3: const pw.FlexColumnWidth(1.5), // Spent
              4: const pw.FlexColumnWidth(1.5), // Remaining
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Month', bold: true),
                  _buildTableCell('Category', bold: true),
                  _buildTableCell('Limit', bold: true),
                  _buildTableCell('Spent', bold: true),
                  _buildTableCell('Remaining', bold: true),
                ],
              ),
              // Data
              ...budgets.map((budget) {
                final spentKey = '${budget.year}-${budget.month}-${budget.category}';
                final spent = spentMap[spentKey] ?? 0.0;
                final remaining = budget.limit - spent;

                return pw.TableRow(
                  children: [
                    _buildTableCell('${budget.month}/${budget.year}'),
                    _buildTableCell(budget.category),
                    _buildTableCell(_formatCurrency(budget.limit)),
                    _buildTableCell(_formatCurrency(spent)),
                    _buildTableCell(
                      _formatCurrency(remaining),
                      color: remaining >= 0 ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Build savings goals page
  Future<pw.Page> _buildSavingsGoalsPage() async {
    final goals = await AppDatabase.getGoals();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader('Savings Goals'),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5), // Name
              1: const pw.FlexColumnWidth(1.5), // Target
              2: const pw.FlexColumnWidth(1.5), // Saved
              3: const pw.FlexColumnWidth(1.5), // Progress
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Goal', bold: true),
                  _buildTableCell('Target', bold: true),
                  _buildTableCell('Saved', bold: true),
                  _buildTableCell('Progress', bold: true),
                ],
              ),
              // Data
              ...goals.map((goal) {
                final saved = _getSavedForGoal(goal);
                final progress = goal.target > 0
                    ? (saved / goal.target * 100)
                    : 0.0;

                return pw.TableRow(
                  children: [
                    _buildTableCell(goal.name),
                    _buildTableCell(_formatCurrency(goal.target)),
                    _buildTableCell(_formatCurrency(saved)),
                    _buildTableCell(
                      '${progress.toStringAsFixed(1)}%',
                      color: progress >= 100 ? PdfColors.green700 : PdfColors.blue700,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Build header widget
  pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build summary row
  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    PdfColor? valueColor,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor ?? PdfColors.black,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build table cell
  pw.Widget _buildTableCell(
    String text, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  /// Save PDF file
  Future<String> _savePdfFile(pw.Document pdf, ExportConfig config) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${directory.path}/exports');

    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final fileName = config.getFileName();
    final file = File('${exportsDir.path}/$fileName');

    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Get filtered transactions
  Future<List<Transaction>> _getFilteredTransactions(ExportConfig config) async {
    var transactions = await AppDatabase.getTransactions();

    if (config.startDate != null) {
      transactions = transactions
          .where((t) =>
              t.date.isAfter(config.startDate!) ||
              t.date.isAtSameMomentAs(config.startDate!))
          .toList();
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
      transactions = transactions
          .where((t) =>
              t.date.isBefore(endOfDay) || t.date.isAtSameMomentAs(endOfDay))
          .toList();
    }

    if (config.categoryFilter != null && config.categoryFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) => config.categoryFilter!.contains(t.category))
          .toList();
    }

    if (config.accountFilter != null && config.accountFilter!.isNotEmpty) {
      transactions = transactions
          .where((t) =>
              t.accountId != null && config.accountFilter!.contains(t.accountId))
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
      final date = DateTime(now.year, now.month - i);
      final budgets = await AppDatabase.getBudgets(date.month, date.year);
      allBudgets.addAll(budgets);
    }

    return allBudgets;
  }

  /// Format date
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }
}
