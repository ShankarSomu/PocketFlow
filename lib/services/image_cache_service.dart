import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Singleton service for caching images with memory and disk persistence
class ImageCacheService {
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();
  static final ImageCacheService _instance = ImageCacheService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50; // Max images in memory
  static const int _maxDiskCacheSizeMB = 100;

  Directory? _cacheDir;

  /// Initialize cache directory
  Future<void> init() async {
    if (_cacheDir != null) return;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/image_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    _cleanupOldCache();
  }

  /// Get cached image or download and cache it
  Future<Uint8List?> getImage(String url) async {
    await init();

    // Check memory cache first
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }

    // Check disk cache
    final cacheKey = _getCacheKey(url);
    final cacheFile = File('${_cacheDir!.path}/$cacheKey');

    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _addToMemoryCache(url, bytes);
      return bytes;
    }

    // Download and cache
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _saveToDisk(cacheKey, bytes);
        _addToMemoryCache(url, bytes);
        return bytes;
      }
    } catch (e) {
      debugPrint('Failed to download image: $e');
    }

    return null;
  }

  /// Cache image from bytes
  Future<void> cacheImageBytes(String key, Uint8List bytes) async {
    await init();
    final cacheKey = _getCacheKey(key);
    await _saveToDisk(cacheKey, bytes);
    _addToMemoryCache(key, bytes);
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    await init();
    _memoryCache.clear();
    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Get cache size in MB
  Future<double> getCacheSizeMB() async {
    await init();
    if (!await _cacheDir!.exists()) return 0;

    int totalSize = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize / (1024 * 1024);
  }

  void _addToMemoryCache(String url, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry (first key)
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[url] = bytes;
  }

  Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    final file = File('${_cacheDir!.path}/$cacheKey');
    await file.writeAsBytes(bytes);
  }

  String _getCacheKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  Future<void> _cleanupOldCache() async {
    final sizeMB = await getCacheSizeMB();
    if (sizeMB > _maxDiskCacheSizeMB) {
      // Delete oldest files until under limit
      final files = await _cacheDir!
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .toList();

      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      int deletedSize = 0;
      for (final file in files) {
        if (sizeMB - (deletedSize / (1024 * 1024)) <= _maxDiskCacheSizeMB * 0.8) {
          break;
        }
        deletedSize += await file.length();
        await file.delete();
      }
    }
  }
}

/// Cached network image widget with loading and error states
class CachedImage extends StatefulWidget {

  const CachedImage({
    required this.imageUrl, super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final bytes = await ImageCacheService().getImage(widget.imageUrl!);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
          _error = bytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_loading) {
      child = widget.placeholder ??
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          );
    } else if (_error || _imageBytes == null) {
      child = widget.errorWidget ??
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: (widget.width ?? 40) * 0.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          );
    } else {
      child = Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}

