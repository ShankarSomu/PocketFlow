import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';

/// Drop-in header widget showing the current filter label. Tap to open picker.
class GlobalFilterButton extends StatelessWidget {
  /// Set [light] to true when the button sits on a dark/gradient background.
  final bool light;
  const GlobalFilterButton({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTimeFilter,
      builder: (context, _) => GestureDetector(
        onTap: () => showTimeFilterSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: light 
              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.18) 
              : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: light ? null : ThemeService.instance.primaryShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 13,
                  color: light ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
              Text(
                appTimeFilter.current.shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: light ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                  color: light ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the global time filter bottom sheet.
void showTimeFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimeFilterSheet(parentContext: context),
  );
}

class _TimeFilterSheet extends StatefulWidget {
  final BuildContext parentContext;
  const _TimeFilterSheet({required this.parentContext});

  @override
  State<_TimeFilterSheet> createState() => _TimeFilterSheetState();
}

class _TimeFilterSheetState extends State<_TimeFilterSheet> {
  bool _showCustom = false;
  int _customMode = 0; // 0=Month, 1=Year, 2=Date Range
  int _navYear = DateTime.now().year;

  static const _pastPresets = [
    TimeFilterKind.thisMonth,
    TimeFilterKind.lastMonth,
    TimeFilterKind.rolling7,
    TimeFilterKind.rolling30,
    TimeFilterKind.rolling90,
    TimeFilterKind.quarter,
    TimeFilterKind.year,
    TimeFilterKind.allTime,
  ];

  static const _futurePresets = [
    TimeFilterKind.nextMonth,
    TimeFilterKind.next3Months,
    TimeFilterKind.next6Months,
  ];

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  void _applyAndClose(VoidCallback fn) {
    fn();
    Navigator.pop(context);
  }

  Widget _buildModeChips() {
    final modes = ['Month', 'Year', 'Date Range'];
    return Row(
      children: [
        for (int i = 0; i < modes.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i < modes.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _customMode = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _customMode == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _customMode == i ? ThemeService.instance.primaryShadow : null,
                  border: Border.all(
                    color: _customMode == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  modes[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _customMode == i ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
              onPressed: () => setState(() => _navYear--),
            ),
            Text(
              '$_navYear',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
              onPressed: () => setState(() => _navYear++),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: List.generate(12, (i) {
            final monthStart = DateTime(_navYear, i + 1, 1);
            final monthEnd = DateTime(_navYear, i + 2, 1).subtract(const Duration(seconds: 1));
            final cur = appTimeFilter.current;
            final isSelected = cur.kind == TimeFilterKind.custom &&
                cur.from.year == _navYear && cur.from.month == i + 1 && cur.from.day == 1;
            return GestureDetector(
              onTap: () => _applyAndClose(
                () => appTimeFilter.selectCustom(monthStart, monthEnd),
              ), // year grid uses same pattern
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? ThemeService.instance.primaryShadow : null,
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  _monthNames[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildYearGrid() {
    final now = DateTime.now();
    final years = List.generate(now.year - 2019 + 5, (i) => 2020 + i);
    final cur = appTimeFilter.current;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: years.map((y) {
        final isSelected = cur.kind == TimeFilterKind.custom &&
            cur.from.year == y && cur.from.month == 1 && cur.from.day == 1;
        return GestureDetector(
          onTap: () => _applyAndClose(() => appTimeFilter.selectCustom(
            DateTime(y, 1, 1),
            DateTime(y + 1, 1, 1).subtract(const Duration(seconds: 1)),
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected ? ThemeService.instance.primaryShadow : null,
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(
              '$y',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRangePicker(TimeFilter cur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (cur.kind == TimeFilterKind.custom)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Current: ${cur.label}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        Text(
          'Pick any start & end date, including future dates for planning.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            final range = await showDateRangePicker(
              context: widget.parentContext,
              firstDate: DateTime(2000),
              lastDate: DateTime(DateTime.now().year + 5, 12, 31),
              initialDateRange: cur.kind == TimeFilterKind.custom
                  ? DateTimeRange(start: cur.from, end: cur.to)
                  : null,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: Theme.of(ctx).colorScheme.primary,
                    onPrimary: Theme.of(ctx).colorScheme.onPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (range != null) {
              appTimeFilter.selectCustom(
                range.start,
                DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              gradient: ThemeService.instance.cardGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: ThemeService.instance.primaryShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                const SizedBox(width: 8),
                Text('Pick Date Range',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTimeFilter,
      builder: (_, __) {
        final current = appTimeFilter.current;
        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Handle --
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Time Period',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  'Currently: ${current.label}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 16),
                // -- Past & Present presets --
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _pastPresets)
                      _PresetChip(
                        kind: kind,
                        selected: current.kind == kind,
                        onTap: () {
                          appTimeFilter.select(kind);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // -- Plan Ahead presets --
                Text('PLAN AHEAD',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _futurePresets)
                      _PresetChip(
                        kind: kind,
                        selected: current.kind == kind,
                        onTap: () {
                          appTimeFilter.select(kind);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                // -- Custom picker --
                GestureDetector(
                  onTap: () => setState(() => _showCustom = !_showCustom),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _showCustom ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _showCustom ? ThemeService.instance.primaryShadow : null,
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: _showCustom ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Custom',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                              Text(
                                current.kind == TimeFilterKind.custom
                                    ? current.label
                                    : 'Pick month, year or date range',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: current.kind == TimeFilterKind.custom
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showCustom ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showCustom) ...[
                  const SizedBox(height: 12),
                  _buildModeChips(),
                  const SizedBox(height: 8),
                  if (_customMode == 0) _buildMonthGrid(),
                  if (_customMode == 1) _buildYearGrid(),
                  if (_customMode == 2) _buildRangePicker(current),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final TimeFilterKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? ThemeService.instance.primaryShadow : null,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          kind.displayName,
          style: TextStyle(
            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
