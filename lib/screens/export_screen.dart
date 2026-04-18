import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database.dart';
import '../models/export_models.dart';
import '../services/json_export_service.dart';
import '../services/csv_export_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';

/// Screen for exporting financial data in various formats
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  final _selectedDataTypes = <ExportDataType>{
    ExportDataType.transactions,
  };

  DateTime? _startDate;
  DateTime? _endDate;
  final _selectedCategories = <String>{};
  final _selectedAccounts = <int>{};
  bool _includeDeleted = false;
  bool _includeMetadata = true;

  // PDF specific options
  String _pdfTitle = 'Financial Report';
  bool _pdfIncludeCoverPage = true;
  bool _pdfIncludeSummary = true;

  // CSV specific options
  CsvTemplate _csvTemplate = CsvTemplate.detailed;

  bool _exporting = false;
  ExportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _performExport() async {
    setState(() {
      _exporting = true;
      _lastResult = null;
    });

    try {
      final config = ExportConfig(
        format: _selectedFormat,
        dataTypes: _selectedDataTypes.toList(),
        startDate: _startDate,
        endDate: _endDate,
        categoryFilter: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
        accountFilter: _selectedAccounts.isEmpty ? null : _selectedAccounts.toList(),
        includeDeleted: _includeDeleted,
        includeMetadata: _includeMetadata,
      );

      ExportResult result;

      switch (_selectedFormat) {
        case ExportFormat.json:
          final service = JsonExportService();
          result = await service.export(config);
          break;

        case ExportFormat.csv:
          final service = CsvExportService();
          result = await service.export(config, template: _csvTemplate);
          break;

        case ExportFormat.excel:
          final service = ExcelExportService();
          result = await service.export(config);
          break;

        case ExportFormat.pdf:
          final service = PdfExportService();
          final reportConfig = PdfReportConfig(
            title: _pdfTitle,
            includeCoverPage: _pdfIncludeCoverPage,
            includeSummary: _pdfIncludeSummary,
          );
          result = await service.export(config, reportConfig);
          break;
      }

      if (mounted) {
        setState(() {
          _lastResult = result;
          _exporting = false;
        });

        if (result.success) {
          _showSuccessDialog(result);
        } else {
          _showErrorDialog(result.error ?? 'Unknown error');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format: ${result.format.displayName}'),
            const SizedBox(height: 8),
            Text('File: ${result.fileName}'),
            const SizedBox(height: 8),
            Text('Size: ${result.formattedSize}'),
            const SizedBox(height: 8),
            Text('Time: ${result.formattedDuration}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareFile(result.filePath!);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'PocketFlow Export',
        text: 'Financial data export from PocketFlow',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Format selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Format',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExportFormat.values.map((format) {
                      final isSelected = _selectedFormat == format;
                      return ChoiceChip(
                        label: Text(format.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedFormat = format);
                        },
                        avatar: isSelected
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getFormatDescription(_selectedFormat),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data types selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data to Export',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...ExportDataType.values.map((type) {
                    return CheckboxListTile(
                      title: Text(type.displayName),
                      value: _selectedDataTypes.contains(type),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedDataTypes.add(type);
                          } else {
                            _selectedDataTypes.remove(type);
                          }
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Date range
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Range',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_getDateRangeText()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Format-specific options
          if (_selectedFormat == ExportFormat.pdf) _buildPdfOptions(),
          if (_selectedFormat == ExportFormat.csv) _buildCsvOptions(),

          const SizedBox(height: 16),

          // Additional options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('Include metadata'),
                    subtitle: const Text('App version, export date, statistics'),
                    value: _includeMetadata,
                    onChanged: (checked) {
                      setState(() => _includeMetadata = checked ?? true);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Include deleted items'),
                    subtitle: const Text('Items in trash/recycle bin'),
                    value: _includeDeleted,
                    onChanged: (checked) {
                      setState(() => _includeDeleted = checked ?? false);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Export button
          FilledButton.icon(
            onPressed: _exporting || _selectedDataTypes.isEmpty
                ? null
                : _performExport,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            label: Text(_exporting ? 'Exporting...' : 'Export Data'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),

          if (_lastResult != null && _lastResult!.success) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last Export',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'File: ${_lastResult!.fileName}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Size: ${_lastResult!.formattedSize}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _shareFile(_lastResult!.filePath!),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Report Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: _pdfTitle),
              onChanged: (value) => _pdfTitle = value,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Include cover page'),
              value: _pdfIncludeCoverPage,
              onChanged: (checked) {
                setState(() => _pdfIncludeCoverPage = checked ?? true);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Include summary page'),
              value: _pdfIncludeSummary,
              onChanged: (checked) {
                setState(() => _pdfIncludeSummary = checked ?? true);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CsvTemplate>(
              value: _csvTemplate,
              decoration: const InputDecoration(
                labelText: 'Template',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: CsvTemplate.values.map((template) {
                return DropdownMenuItem(
                  value: template,
                  child: Text(_getCsvTemplateName(template)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _csvTemplate = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'Structured data format, good for re-importing and archival';
      case ExportFormat.csv:
        return 'Spreadsheet format, compatible with Excel and Google Sheets';
      case ExportFormat.excel:
        return 'Native Excel format with multiple sheets and formatting';
      case ExportFormat.pdf:
        return 'Professional report format, ideal for printing and sharing';
    }
  }

  String _getCsvTemplateName(CsvTemplate template) {
    switch (template) {
      case CsvTemplate.simple:
        return 'Simple (Date, Type, Amount, Category)';
      case CsvTemplate.detailed:
        return 'Detailed (All fields)';
      case CsvTemplate.taxPrep:
        return 'Tax Preparation (Tax-relevant fields)';
      case CsvTemplate.custom:
        return 'Custom (Choose columns)';
    }
  }

  String _getDateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'Select date range';
    }
    final formatter = DateFormat('MMM d, yyyy');
    return '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
  }
}
