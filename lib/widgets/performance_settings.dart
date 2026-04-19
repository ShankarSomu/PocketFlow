import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/settings/components/settings_widgets.dart';
import '../services/image_cache_service.dart';

class PerformanceSettings extends StatefulWidget {
  const PerformanceSettings({super.key});

  @override
  State<PerformanceSettings> createState() => _PerformanceSettingsState();
}

class _PerformanceSettingsState extends State<PerformanceSettings> {
  bool _reduceAnimations = false;
  bool _loading = true;
  double _cacheSizeMB = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheSize = await ImageCacheService().getCacheSizeMB();
    
    if (mounted) {
      setState(() {
        _reduceAnimations = prefs.getBool('reduce_animations') ?? false;
        _cacheSizeMB = cacheSize;
        _loading = false;
      });
    }
  }

  Future<void> _toggleReduceAnimations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_animations', value);
    setState(() => _reduceAnimations = value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value 
              ? 'Animations reduced. Restart app for full effect.' 
              : 'Animations enabled. Restart app for full effect.'
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearImageCache() async {
    await ImageCacheService().clearCache();
    final newSize = await ImageCacheService().getCacheSizeMB();
    
    if (mounted) {
      setState(() => _cacheSizeMB = newSize);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image cache cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reduce animations toggle
        ToggleRow(
          icon: Icons.animation_rounded,
          title: 'Reduce Animations',
          subtitle: 'Disable decorative animations for better performance',
          value: _reduceAnimations,
          onChanged: _toggleReduceAnimations,
        ),
        
        Divider(height: 24, color: Theme.of(context).colorScheme.outlineVariant),
        
        // Image cache info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Image Cache',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cache size: ${_cacheSizeMB.toStringAsFixed(2)} MB',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  TextButton(
                    onPressed: _cacheSizeMB > 0 ? _clearImageCache : null,
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Cached images load faster and use less data',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Performance tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Performance Tips',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTip('Close unused apps to free up memory'),
              _buildTip('Enable "Reduce animations" on older devices'),
              _buildTip('Clear image cache if storage is low'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

