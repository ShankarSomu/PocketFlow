import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Image optimization utilities
class ImageOptimizer {
  /// Load and cache image from assets
  static Future<ImageProvider> loadAssetImage(
    String path, {
    ImageCacheConfig? cacheConfig,
  }) async {
    final provider = AssetImage(path);
    
    // Precache the image
    await precacheImage(provider, 
      NavigatorState as BuildContext, // This needs proper context
    );
    
    return provider;
  }

  /// Create memory image with caching
  static ImageProvider createMemoryImage(
    Uint8List bytes, {
    double scale = 1.0,
  }) {
    return MemoryImage(bytes, scale: scale);
  }

  /// Get image cache size
  static int getImageCacheSize() {
    return PaintingBinding.instance.imageCache.currentSize;
  }

  /// Clear image cache
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Configure image cache
  static void configureImageCache({
    int? maxSize,
    int? maxByteSize,
  }) {
    final imageCache = PaintingBinding.instance.imageCache;
    if (maxSize != null) {
      imageCache.maximumSize = maxSize;
    }
    if (maxByteSize != null) {
      imageCache.maximumSizeBytes = maxByteSize;
    }
  }
}

/// Image cache configuration
class ImageCacheConfig {
  final int maxSize;
  final int maxSizeBytes;

  const ImageCacheConfig({
    this.maxSize = 1000,
    this.maxSizeBytes = 100 << 20, // 100 MB
  });

  static const ImageCacheConfig defaultConfig = ImageCacheConfig();
  
  static const ImageCacheConfig small = ImageCacheConfig(
    maxSize: 100,
    maxSizeBytes: 20 << 20, // 20 MB
  );

  static const ImageCacheConfig large = ImageCacheConfig(
    maxSize: 2000,
    maxSizeBytes: 200 << 20, // 200 MB
  );
}

/// Cached network image widget (simplified version)
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('asset://')) {
      final assetPath = imageUrl.replaceFirst('asset://', '');
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width?.toInt(),
        cacheHeight: height?.toInt(),
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? const Icon(Icons.error);
        },
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Icon(Icons.broken_image);
      },
    );
  }
}

/// Asset image preloader
class AssetImagePreloader {
  static final Map<String, ImageProvider> _cache = {};

  /// Preload multiple images
  static Future<void> preloadImages(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    final futures = assetPaths.map((path) => preloadImage(context, path));
    await Future.wait(futures);
  }

  /// Preload single image
  static Future<void> preloadImage(
    BuildContext context,
    String assetPath,
  ) async {
    if (_cache.containsKey(assetPath)) return;

    final provider = AssetImage(assetPath);
    _cache[assetPath] = provider;
    await precacheImage(provider, context);
  }

  /// Get cached image
  static ImageProvider? getCached(String assetPath) {
    return _cache[assetPath];
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
  }
}
