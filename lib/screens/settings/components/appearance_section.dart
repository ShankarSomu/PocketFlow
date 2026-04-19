import 'package:flutter/material.dart';
import '../../../../services/theme_service.dart';
import 'settings_widgets.dart';

class AppearanceSection extends StatefulWidget {
  const AppearanceSection({super.key});
  
  @override
  State<AppearanceSection> createState() => AppearanceSectionState();
}

class AppearanceSectionState extends State<AppearanceSection> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Accent Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppAccentColor.values.map((accent) {
              final color = ThemeService.accentColors[accent]!;
              final name = ThemeService.accentNames[accent]!;
              final selected = ts.accent == accent;
              return GestureDetector(
                onTap: () => ts.setAccent(accent),
                child: Tooltip(
                  message: name,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.onPrimary : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: selected ? 0.5 : 0.2),
                          blurRadius: selected ? 10 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Contrast',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Row(
            children: [
              Icon(Icons.contrast_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              Expanded(
                child: Slider(
                  value: ts.contrast,
                  min: 0.7,
                  max: 1.3,
                  divisions: 30,
                  label: '${((ts.contrast - 0.7) / 0.6 * 100).round()}%',
                  onChanged: ts.setContrast,
                ),
              ),
              Text('${((ts.contrast - 0.7) / 0.6 * 100).round()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Text Size',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Row(
            children: [
              Icon(Icons.text_fields_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              Expanded(
                child: Slider(
                  value: ts.textSizeIndex.toDouble(),
                  max: 2,
                  divisions: 2,
                  label: ts.textSizeIndex == 0 ? 'Small' : ts.textSizeIndex == 1 ? 'Normal' : 'Large',
                  onChanged: (v) => ts.setTextSizeIndex(v.toInt()),
                ),
              ),
              Text(ts.textSizeIndex == 0 ? 'Small (85%)' : ts.textSizeIndex == 1 ? 'Normal (100%)' : 'Large (120%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          ToggleRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Left-Handed Mode',
            subtitle: 'Moves FAB to left side',
            value: ts.leftHanded,
            onChanged: ts.setLeftHanded,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Theme',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Row(
            children: [AppThemeMode.light, AppThemeMode.dark].map((m) {
              final selected = ts.mode == m;
              final label = m == AppThemeMode.light ? 'Light' : 'Dark';
              final icon = m == AppThemeMode.light
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded;
              return Expanded(
                child: GestureDetector(
                  onTap: () => ts.setMode(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: m != AppThemeMode.dark ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? ts.primaryColor : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 20,
                            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

