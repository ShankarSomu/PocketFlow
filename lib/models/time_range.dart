/// Represents a time range with current and previous period for comparison
class TimeRange {
  final DateTime from;
  final DateTime to;
  final DateTime prevFrom;
  final DateTime prevTo;

  const TimeRange({
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
  });

  /// Create a month range
  factory TimeRange.month(int month, int year) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    final prevFrom = DateTime(year, month - 1, 1);
    final prevTo = DateTime(year, month, 0, 23, 59, 59);

    return TimeRange(
      from: from,
      to: to,
      prevFrom: prevFrom,
      prevTo: prevTo,
    );
  }

  /// Create a year range
  factory TimeRange.year(int year) {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59);
    final prevFrom = DateTime(year - 1, 1, 1);
    final prevTo = DateTime(year - 1, 12, 31, 23, 59, 59);

    return TimeRange(
      from: from,
      to: to,
      prevFrom: prevFrom,
      prevTo: prevTo,
    );
  }

  /// Create a custom range with automatic previous period calculation
  factory TimeRange.custom(DateTime from, DateTime to) {
    final duration = to.difference(from);
    final prevFrom = from.subtract(duration);
    final prevTo = from.subtract(const Duration(seconds: 1));

    return TimeRange(
      from: from,
      to: to,
      prevFrom: prevFrom,
      prevTo: prevTo,
    );
  }

  /// Current period duration in days
  int get durationInDays => to.difference(from).inDays + 1;

  /// Get month from the starting date (for budget filtering)
  int get budgetMonth => from.month;

  /// Get year from the starting date (for budget filtering)
  int get budgetYear => from.year;

  /// Check if a date falls within the current range
  bool contains(DateTime date) {
    return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
        date.isBefore(to.add(const Duration(seconds: 1)));
  }

  @override
  String toString() {
    return 'TimeRange(from: $from, to: $to)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimeRange &&
        other.from == from &&
        other.to == to &&
        other.prevFrom == prevFrom &&
        other.prevTo == prevTo;
  }

  @override
  int get hashCode {
    return from.hashCode ^ to.hashCode ^ prevFrom.hashCode ^ prevTo.hashCode;
  }
}
