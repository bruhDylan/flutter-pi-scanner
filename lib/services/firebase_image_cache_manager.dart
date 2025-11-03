import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Custom CacheManager for Firebase images with improved settings
/// ✅ Web-compatible: uses in-memory cache on web, file cache on mobile
class FirebaseImageCacheManager {
  static const key = 'firebaseImageCache';

  static final BaseCacheManager instance = kIsWeb
      ? CacheManager(
          Config(
            key,
            stalePeriod: const Duration(days: 7), // Shorter for web
            maxNrOfCacheObjects: 200, // Reduced for web memory limits
            // ✅ No repo specified for web - uses in-memory storage
            fileService: HttpFileService(),
          ),
        )
      : CacheManager(
          Config(
            key,
            stalePeriod: const Duration(days: 30), // Full duration for mobile
            maxNrOfCacheObjects: 500, // More images for mobile
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );

  /// Check if an image URL is already cached
  static Future<bool> isCached(String url) async {
    try {
      final fileInfo = await instance.getFileFromCache(url);
      return fileInfo != null;
    } catch (e) {
      // Graceful fallback for web
      return false;
    }
  }

  /// Clear all cached images (use sparingly)
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();
    } catch (e) {
      print('⚠️ Failed to clear cache: $e');
    }
  }

  /// Preload a single image into cache
  static Future<void> preloadImage(String url) async {
    try {
      await instance.downloadFile(url);
    } catch (e) {
      print('⚠️ Failed to preload $url: $e');
    }
  }
  
  /// Batch preload multiple images (useful for galleries)
  static Future<void> preloadImages(List<String> urls) async {
    await Future.wait(
      urls.map((url) => preloadImage(url)),
      eagerError: false, // Continue even if some fail
    );
  }
}