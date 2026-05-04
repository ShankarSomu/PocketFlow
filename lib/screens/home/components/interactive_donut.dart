import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/color_extensions.dart';
import '../../../../core/formatters.dart';
import '../../../../theme/category_colors.dart';
import '../../../widgets/ui/panel.dart';
import '../../shared/shared.dart';
import '../../transactions/transactions_screen.dart';

/// Interactive donut chart showing spending by category
class InteractiveDonut extends StatefulWidget {

  const InteractiveDonut({
    required this.categorySpend, super.key,
  });
  final Map<String, double> categorySpend;

  @override
  State<InteractiveDonut> createState() => _InteractiveDonutState();
}

class _InteractiveDonutState extends State<InteractiveDonut>
    with SingleTickerProviderStateMixin {
  int? _selectedIdx;
  late AnimationController _controller;
  late Animation<double> _animation;

  List<Color> get _colors => CategoryColors.getChartPalette(
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(InteractiveDonut old) {
    super.didUpdateWidget(old);
    if (old.categorySpend != widget.categorySpend) {
      _selectedIdx = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MapEntry<String, double>> _buildItems() {
    final all = widget.categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (all.length <= 6) return all;
    final top5 = all.take(5).toList();
    final rest = all.skip(5).fold(0.0, (s, e) => s + e.value);
    return [...top5, MapEntry('Others', rest)];
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final total = items.fold(0.0, (s, e) => s + e.value);

    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Spend by Category',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectedIdx != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedIdx = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: context.colors.onSurface.subtle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.pie_chart_outline_rounded,
                      size: 40, color: context.colors.onSurface.faint),
                  const SizedBox(height: 8),
                  Text('No expenses recorded',
                      style: TextStyle(color: context.colors.onSurface.faint, fontSize: 12)),
                ]),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  // ── Donut ──
                  SizedBox(
                    width: 155,
                    height: 155,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, __) => CustomPaint(
                        painter: InteractiveDonutPainter(
                          items: items,
                          colors: _colors,
                          selectedIdx: _selectedIdx,
                          progress: _animation.value,
                          strokeColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: GestureDetector(
                          onTapDown: (_) {
                            if (_selectedIdx != null) {
                              // Navigate to transactions with category filter
                              final category = items[_selectedIdx!].key;
                              if (category != 'Others') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => TransactionsScreen(
                                      initialCategory: category,
                                      initialFilterType: 'expense',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              setState(() => _selectedIdx = null);
                            }
                          },
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _selectedIdx == null
                                  ? Column(
                                      key: const ValueKey('total'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(CurrencyFormatter.formatCompact(total),
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: context.colors.onSurface)),
                                        Text('expenses',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: context.colors.onSurface.subtle)),
                                      ],
                                    )
                                  : Column(
                                      key: ValueKey('sel_$_selectedIdx'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          total > 0
                                              ? '${(items[_selectedIdx!].value / total * 100).toStringAsFixed(1)}%'
                                              : '0%',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: _colors[_selectedIdx! %
                                                  _colors.length]),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            _titleCase(items[_selectedIdx!].key),
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: context.colors.onSurface.subtle,
                                                fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatNoDecimals(
                                              items[_selectedIdx!].value),
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: context.colors.onSurface.subtle),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Legend ──
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: items.asMap().entries.map((e) {
                        final color = _colors[e.key % _colors.length];
                        final isSelected = _selectedIdx == e.key;
                        final isOtherSel =
                            _selectedIdx != null && !isSelected;
                        final pct = total > 0
                            ? (e.value.value / total * 100)
                                .toStringAsFixed(0)
                            : '0';
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selectedIdx = isSelected ? null : e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.veryFaint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: color.faint)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isSelected ? 10 : 8,
                                  height: isSelected ? 10 : 8,
                                  decoration: BoxDecoration(
                                    color: isOtherSel
                                        ? color.faint
                                        : color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _titleCase(e.value.key),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isOtherSel
                                          ? context.colors.onSurface.faint
                                          : context.colors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('$pct%',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isOtherSel
                                            ? context.colors.onSurface.faint
                                            : color)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class InteractiveDonutPainter extends CustomPainter {

  InteractiveDonutPainter({
    required this.items,
    required this.colors,
    required this.selectedIdx,
    required this.progress,
    required this.strokeColor,
  });
  final List<MapEntry<String, double>> items;
  final List<Color> colors;
  final int? selectedIdx;
  final double progress;
  final Color strokeColor;

  static const double _strokeWidth = 20.0;
  static const double _expansion = 8.0;
  static const double _gap = 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius =
        (size.shortestSide / 2) - _strokeWidth / 2 - _expansion - 2;

    // Track ring
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    double currentAngle = -pi / 2;
    for (int i = 0; i < items.length; i++) {
      final fraction = items[i].value / total;
      final sweep = 2 * pi * fraction * progress;
      if (sweep <= 0) continue;

      final isSelected = selectedIdx == i;
      final isOtherSel = selectedIdx != null && !isSelected;
      final color = colors[i % colors.length];
      final midAngle = currentAngle + sweep / 2;
      final drawSweep = sweep - _gap;

      if (drawSweep <= 0) {
        currentAngle += 2 * pi * fraction * progress;
        continue;
      }

      final offsetDist = isSelected ? _expansion * 0.7 : 0.0;
      final drawCenter = center +
          Offset(cos(midAngle) * offsetDist, sin(midAngle) * offsetDist);

      if (isSelected) {
        canvas.drawArc(
          Rect.fromCircle(center: drawCenter, radius: baseRadius),
          currentAngle + _gap / 2,
          drawSweep,
          false,
          Paint()
            ..color = color.faint
            ..style = PaintingStyle.stroke
            ..strokeWidth = _strokeWidth + 8
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: drawCenter, radius: baseRadius),
        currentAngle + _gap / 2,
        drawSweep,
        false,
        Paint()
          ..color = isOtherSel ? color.faint : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      currentAngle += 2 * pi * fraction * progress;
    }
  }

  @override
  bool shouldRepaint(InteractiveDonutPainter old) =>
      old.selectedIdx != selectedIdx ||
      old.progress != progress ||
      old.items != items;
}
