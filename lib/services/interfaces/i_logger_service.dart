/// Interface for logging service
abstract class ILoggerService {
  /// Log a database operation
  void db(String operation, {String? detail});

  /// Log a user action
  void userAction(String action, {String? detail});

  /// Log an error
  void error(String message, {dynamic error, StackTrace? stackTrace});

  /// Log info
  void info(String message);

  /// Initialize the logger
  Future<void> init();

  /// Load existing logs
  Future<void> load();

  /// Get all logs
  List<String> getLogs();

  /// Clear all logs
  Future<void> clear();
}
