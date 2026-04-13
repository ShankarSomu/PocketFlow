import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warning, error, debug }
enum LogCategory {
  userAction,    // user tapped/submitted something
  scheduler,     // recurring scheduler runs
  database,      // DB insert/update/delete
  ai,            // AI chat actions
  backup,        // backup/restore
  navigation,    // screen changes
  system,        // app start/stop
  error,         // exceptions
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String action;
  final String? detail;
  final String? error;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.action,
    this.detail,
    this.error,
  });

  Map<String, dynamic> toMap() => {
        'ts': timestamp.toIso8601String(),
        'level': level.name,
        'category': category.name,
        'action': action,
        if (detail != null) 'detail': detail,
        if (error != null) 'error': error,
      };

  String toLogLine() {
    final t = timestamp.toIso8601String().substring(0, 19);
    final lvl = level.name.toUpperCase().padRight(7);
    final cat = '[${category.name}]'.padRight(14);
    final err = error != null ? ' ERROR: $error' : '';
    final det = detail != null ? ' | $detail' : '';
    return '$t $lvl $cat $action$det$err';
  }
}

class AppLogger {
  static const _prefKey = 'app_logs';
  static const _prefLevel = 'log_level';
  static const _maxEntries = 500;
  static final List<LogEntry> _buffer = [];
  static bool _initialized = false;
  static LogLevel _minLevel = LogLevel.info;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadLevel();
    log(LogLevel.info, LogCategory.system, 'App started');
  }

  static Future<void> _loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefLevel) ?? 'info';
    _minLevel = LogLevel.values.firstWhere((l) => l.name == val, orElse: () => LogLevel.info);
  }

  static Future<void> setLevel(LogLevel level) async {
    _minLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLevel, level.name);
  }

  static LogLevel getLevel() => _minLevel;

  // ── Core log method ─────────────────────────────────────────────────────────

  static void log(
    LogLevel level,
    LogCategory category,
    String action, {
    String? detail,
    String? error,
  }) {
    // Skip if below minimum level
    if (level.index < _minLevel.index) return;
    
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      action: action,
      detail: detail,
      error: error,
    );
    _buffer.add(entry);
    if (_buffer.length > _maxEntries) _buffer.removeAt(0);
    
    // Debug print to console
    print('[${level.name.toUpperCase()}] [${category.name}] $action${detail != null ? ' | $detail' : ''}${error != null ? ' ERROR: $error' : ''}');
    
    _persist();
  }

  // ── Convenience methods ─────────────────────────────────────────────────────

  static void userAction(String action, {String? detail}) =>
      log(LogLevel.info, LogCategory.userAction, action, detail: detail);

  static void scheduler(String action, {String? detail}) =>
      log(LogLevel.info, LogCategory.scheduler, action, detail: detail);

  static void db(String action, {String? detail}) =>
      log(LogLevel.debug, LogCategory.database, action, detail: detail);

  static void ai(String action, {String? detail}) =>
      log(LogLevel.info, LogCategory.ai, action, detail: detail);

  static void backup(String action, {String? detail}) =>
      log(LogLevel.info, LogCategory.backup, action, detail: detail);

  static void nav(String screen) =>
      log(LogLevel.debug, LogCategory.navigation, 'Navigate to $screen');

  static void err(String action, dynamic error, {LogCategory? category}) =>
      log(LogLevel.error, category ?? LogCategory.error, action,
          error: error.toString());

  static void warn(String action, {String? detail, LogCategory? category}) =>
      log(LogLevel.warning, category ?? LogCategory.system, action,
          detail: detail);

  // ── Persistence ─────────────────────────────────────────────────────────────

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_buffer.map((e) => e.toMap()).toList());
      await prefs.setString(_prefKey, data);
    } catch (_) {}
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefKey);
      if (data == null) return;
      final list = jsonDecode(data) as List;
      _buffer.clear();
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        _buffer.add(LogEntry(
          timestamp: DateTime.parse(m['ts']),
          level: LogLevel.values.firstWhere((l) => l.name == m['level'],
              orElse: () => LogLevel.info),
          category: LogCategory.values.firstWhere(
              (c) => c.name == m['category'],
              orElse: () => LogCategory.system),
          action: m['action'],
          detail: m['detail'],
          error: m['error'],
        ));
      }
    } catch (_) {}
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  static List<LogEntry> getAll() => List.unmodifiable(_buffer);

  static List<LogEntry> getByCategory(LogCategory cat) =>
      _buffer.where((e) => e.category == cat).toList();

  static List<LogEntry> getErrors() =>
      _buffer.where((e) => e.level == LogLevel.error).toList();

  static String exportText() {
    final buf = StringBuffer();
    buf.writeln('=== PocketFlow Diagnostics ===');
    buf.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buf.writeln('Total entries: ${_buffer.length}');
    buf.writeln('');

    // Summary
    final errors = _buffer.where((e) => e.level == LogLevel.error).length;
    final warnings = _buffer.where((e) => e.level == LogLevel.warning).length;
    buf.writeln('--- Summary ---');
    buf.writeln('Errors: $errors');
    buf.writeln('Warnings: $warnings');
    buf.writeln('');

    // Group by category
    for (final cat in LogCategory.values) {
      final entries = _buffer.where((e) => e.category == cat).toList();
      if (entries.isEmpty) continue;
      buf.writeln('--- ${cat.name.toUpperCase()} (${entries.length}) ---');
      for (final e in entries) {
        buf.writeln(e.toLogLine());
      }
      buf.writeln('');
    }

    return buf.toString();
  }

  static String exportJson() =>
      jsonEncode(_buffer.map((e) => e.toMap()).toList());

  static Future<void> clear() async {
    _buffer.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
