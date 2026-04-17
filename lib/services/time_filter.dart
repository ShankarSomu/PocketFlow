import 'package:flutter/foundation.dart';

// ── Time Filter Kind ──────────────────────────────────────────────────────────

enum TimeFilterKind {
  thisMonth,    // current calendar month
  lastMonth,    // previous calendar month
  quarter,      // current calendar quarter
  year,         // current calendar year
  rolling7,     // rolling last 7 days
  rolling30,    // rolling last 30 days
  rolling90,    // rolling last 90 days
  allTime,      // all records
  nextMonth,    // next calendar month
  next3Months,  // next 3 calendar months
  next6Months,  // next 6 calendar months
  custom,       // user-picked date range
}

extension TimeFilterKindExt on TimeFilterKind {
  String get displayName => switch (this) {
    TimeFilterKind.thisMonth  => 'This Month',
    TimeFilterKind.lastMonth  => 'Last Month',
    TimeFilterKind.quarter    => 'This Quarter',
    TimeFilterKind.year       => 'This Year',
    TimeFilterKind.rolling7   => 'Last 7 Days',
    TimeFilterKind.rolling30  => 'Last 30 Days',
    TimeFilterKind.rolling90  => 'Last 90 Days',
    TimeFilterKind.allTime    => 'All Time',
    TimeFilterKind.nextMonth   => 'Next Month',
    TimeFilterKind.next3Months => 'Next 3 Months',
    TimeFilterKind.next6Months => 'Next 6 Months',
    TimeFilterKind.custom      => 'Custom Range',
  };
}

// ── Time Filter ───────────────────────────────────────────────────────────────

class TimeFilter {
  final TimeFilterKind kind;
  final DateTime from;
  final DateTime to;

  const TimeFilter._(this.kind, this.from, this.to);

  /// Builds a [TimeFilter] for the given [kind] relative to *right now*.
  factory TimeFilter.forKind(TimeFilterKind kind) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (kind) {
      case TimeFilterKind.thisMonth:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.lastMonth:
        final m = now.month == 1 ? 12 : now.month - 1;
        final y = now.month == 1 ? now.year - 1 : now.year;
        return TimeFilter._(
          kind,
          DateTime(y, m, 1),
          DateTime(y, m + 1, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.quarter:
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1; // 1, 4, 7, 10
        return TimeFilter._(
          kind,
          DateTime(now.year, qStart, 1),
          DateTime(now.year, qStart + 3, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.year:
        return TimeFilter._(
          kind,
          DateTime(now.year, 1, 1),
          DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.rolling7:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
          todayEnd,
        );

      case TimeFilterKind.rolling30:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
          todayEnd,
        );

      case TimeFilterKind.rolling90:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89)),
          todayEnd,
        );

      case TimeFilterKind.allTime:
        return TimeFilter._(
          kind,
          DateTime(2000, 1, 1),
          todayEnd,
        );

      case TimeFilterKind.nextMonth:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month + 1, 1),
          DateTime(now.year, now.month + 2, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.next3Months:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month + 1, 1),
          DateTime(now.year, now.month + 4, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.next6Months:
        return TimeFilter._(
          kind,
          DateTime(now.year, now.month + 1, 1),
          DateTime(now.year, now.month + 7, 1).subtract(const Duration(seconds: 1)),
        );

      case TimeFilterKind.custom:
        // Should be created via TimeFilter.custom(); fall back to allTime.
        return TimeFilter._(
          TimeFilterKind.allTime,
          DateTime(2000, 1, 1),
          todayEnd,
        );
    }
  }

  /// Creates a custom date range filter.
  factory TimeFilter.custom(DateTime from, DateTime to) {
    return TimeFilter._(TimeFilterKind.custom, from, to);
  }

  // ── Labels ──────────────────────────────────────────────────────────────────

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Full human label: "April 2026", "Q2 2026", "2026", "Last 30 days"
  String get label => switch (kind) {
    TimeFilterKind.thisMonth || TimeFilterKind.lastMonth =>
        '${_months[from.month - 1]} ${from.year}',
    TimeFilterKind.quarter =>
        'Q${((from.month - 1) ~/ 3) + 1} ${from.year}',
    TimeFilterKind.year    => '${from.year}',
    TimeFilterKind.rolling7  => 'Last 7 days',
    TimeFilterKind.rolling30 => 'Last 30 days',
    TimeFilterKind.rolling90 => 'Last 90 days',
    TimeFilterKind.allTime   => 'All Time',
    TimeFilterKind.nextMonth  => '${_months[from.month - 1]} ${from.year}',
    TimeFilterKind.next3Months => 'Next 3 Months',
    TimeFilterKind.next6Months => 'Next 6 Months',
    TimeFilterKind.custom    =>
        '${_monthsShort[from.month - 1]} ${from.day} – ${_monthsShort[to.month - 1]} ${to.day}, ${to.year}',
  };

  /// Short label for chips: "Apr 2026", "Q2 2026", "7d" etc.
  String get shortLabel => switch (kind) {
    TimeFilterKind.thisMonth || TimeFilterKind.lastMonth =>
        '${_monthsShort[from.month - 1]} ${from.year}',
    TimeFilterKind.quarter =>
        'Q${((from.month - 1) ~/ 3) + 1} ${from.year}',
    TimeFilterKind.year    => '${from.year}',
    TimeFilterKind.rolling7  => '7d',
    TimeFilterKind.rolling30 => '30d',
    TimeFilterKind.rolling90 => '90d',
    TimeFilterKind.allTime   => 'All',
    TimeFilterKind.nextMonth  => '${_monthsShort[from.month - 1]} ${from.year}',
    TimeFilterKind.next3Months => 'Next 3M',
    TimeFilterKind.next6Months => 'Next 6M',
    TimeFilterKind.custom    =>
        '${_monthsShort[from.month - 1]} ${from.day} – ${_monthsShort[to.month - 1]} ${to.day}',
  };

  // ── Budget helpers ───────────────────────────────────────────────────────────

  /// Month to use for `getBudgets(month, year)` — the month that contains `from`.
  int get budgetMonth => from.month;
  int get budgetYear  => from.year;

  // ── Previous-period bounds (for % change comparisons) ───────────────────────

  /// End of previous period = 1 second before this period starts.
  DateTime get prevTo => from.subtract(const Duration(seconds: 1));

  /// Start of previous period = same duration before [from].
  DateTime get prevFrom {
    final days = to.difference(from).inDays + 1;
    return from.subtract(Duration(days: days));
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Global time filter state. All screens listen to this via [appTimeFilter].
class TimeFilterNotifier extends ChangeNotifier {
  TimeFilter _current = TimeFilter.forKind(TimeFilterKind.thisMonth);

  TimeFilter get current => _current;

  void select(TimeFilterKind kind) {
    if (kind == TimeFilterKind.custom) return; // use selectCustom() instead
    _current = TimeFilter.forKind(kind);
    notifyListeners();
  }

  void selectCustom(DateTime from, DateTime to) {
    _current = TimeFilter.custom(from, to);
    notifyListeners();
  }
}

/// App-wide singleton. Screens call `appTimeFilter.addListener(_load)` in
/// `initState` and `appTimeFilter.removeListener(_load)` in `dispose`.
final appTimeFilter = TimeFilterNotifier();
