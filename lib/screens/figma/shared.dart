import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';
/// A horizontal bar for selecting the global time filter.
class TimeFilterBar extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const TimeFilterBar({super.key, this.padding = const EdgeInsets.symmetric(vertical: 8)});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTimeFilter,
      builder: (context, _) {
        final current = appTimeFilter.current;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                for (final kind in TimeFilterKind.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(kind.displayName),
                      selected: current.kind == kind,
                      onSelected: (selected) {
                        if (selected) appTimeFilter.select(kind);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: current.kind == kind
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -- Screen header with name + active filter badge -----------------------------

/// Lightweight top bar used across all main screens (Accounts, Budget, etc.).
/// Shows the [title] on the left and the active time-filter as a tappable pill
/// on the right. Reacts automatically when the global filter changes.
class ScreenHeader extends StatelessWidget {
  final String title;
  const ScreenHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Reactive filter badge � tapping opens the picker
          AnimatedBuilder(
            animation: appTimeFilter,
            builder: (context, _) => GestureDetector(
              onTap: () => showTimeFilterSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: ThemeService.instance.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: ThemeService.instance.primaryShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      appTimeFilter.current.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Global filter button ------------------------------------------------------

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
            color: light ? Colors.white.withOpacity(0.18) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: light ? null : ThemeService.instance.primaryShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 13,
                  color: light ? Colors.white : Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
              Text(
                appTimeFilter.current.shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: light ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                  color: light ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Filter sheet --------------------------------------------------------------

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
                  color: _customMode == i ? Theme.of(context).colorScheme.primary : Colors.white,
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
                    color: _customMode == i ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
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
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected ? ThemeService.instance.primaryShadow : null,
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(
              '$y',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
              style: TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600),
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
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF2563EB),
                    onPrimary: Colors.white,
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Pick Date Range',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
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
                      color: Colors.grey[300],
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
                              color: _showCustom ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
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
          color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? ThemeService.instance.primaryShadow : null,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          kind.displayName,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class FigmaSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const FigmaSectionTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class FigmaGradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  const FigmaGradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class FigmaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FigmaPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class FigmaProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const FigmaProgressBar({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0, 1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withOpacity(0.18),
      ),
    );
  }
}

class FigmaBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  const FigmaBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FigmaIconCircle extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final double size;
  const FigmaIconCircle({super.key, required this.label, required this.gradient, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}

// -- Calendar FAB --------------------------------------------------------------

/// Mini circular FAB that opens the global time-filter sheet.
/// Place inside a [Stack] body via [Positioned(bottom: 16, left: 16)].
class CalendarFab extends StatelessWidget {
  const CalendarFab({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showTimeFilterSheet(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.calendar_today_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

// -- Speed Dial FAB ------------------------------------------------------------

/// A single action for [SpeedDialFab].
class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
}

/// Expandable speed-dial FAB.
/// Tap the `+` button to expand mini-FABs above it; tap any action or the
/// main button again to collapse.
class SpeedDialFab extends StatefulWidget {
  final List<SpeedDialAction> actions;

  const SpeedDialFab({super.key, required this.actions});

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-close when this screen becomes inactive in an IndexedStack
    if (!TickerMode.of(context)) _close();
  }

  @override
  void deactivate() {
    _close();
    super.deactivate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    if (_open) {
      setState(() => _open = false);
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Action items � each tappable row (label + icon) triggers the action
        for (final action in widget.actions.reversed)
          FadeTransition(
            opacity: _fade,
            child: SizeTransition(
              sizeFactor: _scale,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _close();
                    action.onPressed();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label bubble (tappable via parent GestureDetector)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Icon circle
                      Material(
                        color: action.color ?? Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(action.icon, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Main FAB
        FloatingActionButton(
          heroTag: null,
          onPressed: _toggleOpen,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          child: Ink(
            decoration: BoxDecoration(
              gradient: ThemeService.instance.cardGradient,
              shape: BoxShape.circle,
              boxShadow: ThemeService.instance.primaryShadow,
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _open ? 0.125 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.add, size: 28, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
