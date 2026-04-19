import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';

/// Drop-in header widget showing the current filter label. Tap to open picker.
class GlobalFilterButton extends StatelessWidget {
  const GlobalFilterButton({super.key, this.light = false});
  /// Set [light] to true when the button sits on a dark/gradient background.
  final bool light;

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
              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.18) 
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
                  color: light ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                  color: light ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
  const _TimeFilterSheet({required this.parentContext});
  final BuildContext parentContext;

  @override
  State<_TimeFilterSheet> createState() => _TimeFilterSheetState();
}

class _TimeFilterSheetState extends State<_TimeFilterSheet> {
  bool _showAdvanced = false;
  bool _showMonthPicker = false;
  bool _showYearPicker = false;
  int _navYear = DateTime.now().year;
  
  // Simplified quick presets
  static const _quickPresets = [
    TimeFilterKind.thisMonth,
    TimeFilterKind.lastMonth,
    TimeFilterKind.nextMonth,
  ];
  
  // Advanced presets
  static const _advancedPresets = [
    TimeFilterKind.rolling7,
    TimeFilterKind.rolling30,
    TimeFilterKind.rolling90,
    TimeFilterKind.quarter,
    TimeFilterKind.year,
    TimeFilterKind.allTime,
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

  Widget _buildMonthGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
              onPressed: () => setState(() => _navYear--),
            ),
            Text(
              '$_navYear',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
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
            final monthStart = DateTime(_navYear, i + 1);
            final monthEnd = DateTime(_navYear, i + 2).subtract(const Duration(seconds: 1));
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
                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
            DateTime(y),
            DateTime(y + 1).subtract(const Duration(seconds: 1)),
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
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 20),
                // -- Date Picker --
                Text('PICK A DATE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _showMonthPicker = !_showMonthPicker;
                          _showYearPicker = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _showMonthPicker 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showMonthPicker
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.calendar_month_rounded, 
                                  color: _showMonthPicker
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  size: 20),
                              const SizedBox(height: 6),
                              Text('Select Month',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _showMonthPicker
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _showYearPicker = !_showYearPicker;
                          _showMonthPicker = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _showYearPicker
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showYearPicker
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.calendar_today_rounded, 
                                  color: _showYearPicker
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  size: 20),
                              const SizedBox(height: 6),
                              Text('Select Year',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _showYearPicker
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showMonthPicker) ...[
                  const SizedBox(height: 16),
                  _buildMonthGrid(),
                ],
                if (_showYearPicker) ...[
                  const SizedBox(height: 16),
                  _buildYearGrid(),
                ],
                const SizedBox(height: 20),
                // -- Quick Options --
                Text('QUICK OPTIONS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (int i = 0; i < _quickPresets.length; i++) ...[
                      Expanded(
                        child: _PresetChip(
                          kind: _quickPresets[i],
                          selected: current.kind == _quickPresets[i],
                          onTap: () {
                            appTimeFilter.select(_quickPresets[i]);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      if (i < _quickPresets.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // -- Advanced Section --
                GestureDetector(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _showAdvanced ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _showAdvanced ? ThemeService.instance.primaryShadow : null,
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: _showAdvanced ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Advanced',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                              Text('More filters & custom ranges',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _showAdvanced ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in _advancedPresets)
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
                  const SizedBox(height: 16),
                  // -- Custom Range Picker --
                  Text('CUSTOM RANGE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      final range = await showDateRangePicker(
                        context: widget.parentContext,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                        initialDateRange: current.kind == TimeFilterKind.custom
                            ? DateTimeRange(start: current.from, end: current.to)
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: ThemeService.instance.cardGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: ThemeService.instance.primaryShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.kind, required this.selected, required this.onTap});
  final TimeFilterKind kind;
  final bool selected;
  final VoidCallback onTap;

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
            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

