import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pocket_flow/sms_engine/export/sms_export_service.dart';

/// Screen for exporting SMS messages as training data
class SmsTrainingExportScreen extends StatefulWidget {
  const SmsTrainingExportScreen({super.key});

  @override
  State<SmsTrainingExportScreen> createState() => _SmsTrainingExportScreenState();
}

class _SmsTrainingExportScreenState extends State<SmsTrainingExportScreen> {
  bool _maskSensitiveData = true;
  SmsExportFormat _selectedFormat = SmsExportFormat.json;
  bool _includeMetadata = true;
  bool _includeTransactionData = false;
  bool _onlySuccessful = false;
  
  DateTime? _startDate;
  DateTime? _endDate;
  
  bool _exporting = false;
  SmsExportResult? _lastResult;
  int _availableMessageCount = 0;
  bool _loadingCount = false;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _loadMessageCount();
  }
  
  Future<void> _loadMessageCount() async {
    setState(() => _loadingCount = true);
    final count = await SmsExportService.getAvailableMessageCount(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _availableMessageCount = count;
        _loadingCount = false;
      });
    }
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
      _loadMessageCount(); // Reload count with new dates
    }
  }

  Future<void> _performExport() async {
    setState(() {
      _exporting = true;
      _lastResult = null;
    });

    try {
      final config = SmsExportConfig(
        maskSensitiveData: _maskSensitiveData,
        format: _selectedFormat,
        includeMetadata: _includeMetadata,
        includeTransactionData: _includeTransactionData,
        onlySuccessfullyParsed: _onlySuccessful,
        startDate: _startDate,
        endDate: _endDate,
      );

      final result = await SmsExportService.exportSmsMessages(config);

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

  void _showSuccessDialog(SmsExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${result.fileName}'),
            const SizedBox(height: 8),
            Text('Messages: ${result.messageCount}'),
            const SizedBox(height: 8),
            Text('Size: ${result.formattedSize}'),
            if (result.maskingSummary != null) ...[
              const SizedBox(height: 16),
              const Text('Masked Data:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('• Amounts: ${result.maskingSummary!.amountsMasked}'),
              Text('• Accounts: ${result.maskingSummary!.accountsMasked}'),
              Text('• Dates: ${result.maskingSummary!.datesMasked}'),
              Text('• References: ${result.maskingSummary!.referencesMasked}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles(
                [XFile(result.filePath)],
                subject: 'SMS Training Data',
              );
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
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Export Failed'),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export SMS Training Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'SMS Training Data Export',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Export your SMS messages with masked sensitive data for training ML models. '
                      'All personal information is replaced with placeholders:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildMaskingExample(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Data Masking Section
            const Text(
              'Data Privacy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Mask Sensitive Data'),
              subtitle: const Text('Replace amounts, accounts, dates, and IDs with placeholders'),
              value: _maskSensitiveData,
              onChanged: (value) => setState(() => _maskSensitiveData = value),
            ),
            const Divider(),

            // Format Section
            const SizedBox(height: 16),
            const Text(
              'Export Format',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SmsExportFormat>(
              segments: const [
                ButtonSegment(
                  value: SmsExportFormat.json,
                  label: Text('JSON'),
                  icon: Icon(Icons.code),
                ),
                ButtonSegment(
                  value: SmsExportFormat.csv,
                  label: Text('CSV'),
                  icon: Icon(Icons.table_chart),
                ),
                ButtonSegment(
                  value: SmsExportFormat.txt,
                  label: Text('TXT'),
                  icon: Icon(Icons.text_snippet),
                ),
              ],
              selected: {_selectedFormat},
              onSelectionChanged: (Set<SmsExportFormat> selection) {
                setState(() => _selectedFormat = selection.first);
              },
            ),
            const SizedBox(height: 24),

            // Options Section
            const Text(
              'Include Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Metadata'),
              subtitle: const Text('Date, source type, masking info'),
              value: _includeMetadata,
              onChanged: (value) => setState(() => _includeMetadata = value ?? true),
            ),
            CheckboxListTile(
              title: const Text('Transaction Data'),
              subtitle: const Text('Parsed transaction details (optional)'),
              value: _includeTransactionData,
              onChanged: (value) => setState(() => _includeTransactionData = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('Only Successfully Parsed'),
              subtitle: const Text('Exclude messages that failed parsing'),
              value: _onlySuccessful,
              onChanged: (value) => setState(() => _onlySuccessful = value ?? false),
            ),
            const Divider(),

            // Date Range Section
            const SizedBox(height: 16),
            const Text(
              'Date Range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(_getDateRangeText()),
              subtitle: const Text('Tap to change date range'),
              onTap: _selectDateRange,
              trailing: const Icon(Icons.edit),
            ),            
            // Message count indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.sms_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  _loadingCount
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Counting messages...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '$_availableMessageCount financial SMS available for export',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ],
              ),
            ),
                        const SizedBox(height: 32),

            // Export Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _performExport,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_exporting ? 'Exporting...' : 'Export SMS Training Data'),
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaskingExample() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Example:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildMaskingRow('Amounts', '₹1,234.56', '₹X,XXX.XX'),
          _buildMaskingRow('Accounts', 'XX1234', 'XXXX'),
          _buildMaskingRow('Dates', '19-Apr-26', '<DATE>'),
          _buildMaskingRow('References', 'Ref: 123456789', '<REF>'),
        ],
      ),
    );
  }

  Widget _buildMaskingRow(String label, String original, String masked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$original → $masked',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'All time';
    }
    final formatter = DateFormat('MMM d, y');
    return '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
  }
}
