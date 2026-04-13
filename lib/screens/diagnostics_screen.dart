import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';
import '../services/auth_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<LogEntry> _logs = [];
  LogCategory? _filterCategory;
  LogLevel? _filterLevel;
  bool _exporting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      var logs = AppLogger.getAll().reversed.toList();
      if (_filterCategory != null) {
        logs = logs.where((e) => e.category == _filterCategory).toList();
      }
      if (_filterLevel != null) {
        logs = logs.where((e) => e.level == _filterLevel).toList();
      }
      _logs = logs;
    });
  }

  Future<void> _exportToDrive() async {
    setState(() { _exporting = true; _message = null; });
    try {
      final folder = await AuthService.getSelectedFolder();
      if (folder == null) {
        setState(() {
          _exporting = false;
          _message = 'No backup folder selected. Set one in Profile first.';
        });
        return;
      }
      await AuthService.exportDiagnostics();
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = 'Diagnostics exported to "${folder.name}" on Google Drive';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = 'Export failed: $e';
      });
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: AppLogger.exportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errors = AppLogger.getErrors().length;
    final total = AppLogger.getAll().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Export to Drive',
            onPressed: _exporting ? null : _exportToDrive,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Logs?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) {
                await AppLogger.clear();
                _refresh();
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: Row(children: [
            _SummaryChip('Total', total.toString(), Colors.blue),
            const SizedBox(width: 8),
            _SummaryChip('Errors', errors.toString(),
                errors > 0 ? Colors.red : Colors.green),
            const Spacer(),
            if (_message != null)
              Expanded(
                child: Text(_message!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),

        // Filter bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            _FilterChip(
              label: 'All',
              selected: _filterCategory == null && _filterLevel == null,
              onTap: () {
                setState(() { _filterCategory = null; _filterLevel = null; });
                _refresh();
              },
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: '🔴 Errors',
              selected: _filterLevel == LogLevel.error,
              color: Colors.red,
              onTap: () {
                setState(() { _filterLevel = LogLevel.error; _filterCategory = null; });
                _refresh();
              },
            ),
            const SizedBox(width: 6),
            ...LogCategory.values.map((cat) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: cat.name,
                selected: _filterCategory == cat,
                onTap: () {
                  setState(() { _filterCategory = cat; _filterLevel = null; });
                  _refresh();
                },
              ),
            )),
          ]),
        ),

        const Divider(height: 1),

        // Log list
        Expanded(
          child: _logs.isEmpty
              ? const Center(
                  child: Text('No logs',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => _LogTile(entry: _logs[i]),
                ),
        ),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? const Color(0xFF6C63FF)).withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? (color ?? const Color(0xFF6C63FF))
                  : Colors.transparent,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? (color ?? const Color(0xFF6C63FF))
                      : Colors.grey,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  Color get _levelColor => switch (entry.level) {
        LogLevel.error => Colors.red,
        LogLevel.warning => Colors.orange,
        LogLevel.debug => Colors.grey,
        _ => Colors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final time = entry.timestamp.toIso8601String().substring(11, 19);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1)),
          left: BorderSide(color: _levelColor, width: 3),
        ),
        color: entry.level == LogLevel.error
            ? Colors.red.withValues(alpha: 0.03)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(time,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _levelColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(entry.category.name,
                style: TextStyle(fontSize: 9, color: _levelColor)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.action,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        if (entry.detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text(entry.detail!,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        if (entry.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text('⚠ ${entry.error!}',
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ),
      ]),
    );
  }
}
