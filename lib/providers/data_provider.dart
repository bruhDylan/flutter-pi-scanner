import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../services/firebase_image_cache_manager.dart';

/// DataProvider stores Oracle APEX data and Firebase image URLs with smart caching and preloading.
class DataProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _apexItems = [];
  List<Map<String, dynamic>> _imageFiles = []; // {name,url,meta,timeCreated}
  bool _loading = false;
  bool _isPreloading = false;

  DataProvider() {
    // Start loading data as soon as provider is created so UI can show latest images quickly.
    fetchData();
  }

  // History cache + timestamp
  DateTime? _historyLastFetch;
  List<Map<String, dynamic>>? _historyCache;

  // Separate APEX cache + timestamp
  DateTime? _apexLastFetch;
  List<Map<String, dynamic>>? _apexCache;

  // Getters
  List<Map<String, dynamic>> get imageFiles => _imageFiles;
  List<Map<String, dynamic>> get apexItems => _apexItems;
  bool get isLoading => _loading;
  bool get isPreloading => _isPreloading;
  DateTime? get historyLastFetch => _historyLastFetch;
  List<Map<String, dynamic>>? get historyCache => _historyCache;
  DateTime? get apexLastFetch => _apexLastFetch;
  List<Map<String, dynamic>>? get apexCache => _apexCache;

  /// Fetch APEX + Firebase images only if empty or stale
  Future<void> fetchDataIfNeeded() async {
    if ((_apexCache == null) || (_historyCache == null)) {
      await fetchData();
      return;
    }

    // Refresh caches if stale
    if (shouldRefreshHistory() || shouldRefreshApex()) {
      await fetchData();
    }
  }

  /// Force fetch data when needed
  Future<void> fetchData({bool forceRefresh = false}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      // Fetch APEX data if missing, stale, or forced
      if (forceRefresh || _apexCache == null || shouldRefreshApex()) {
        await _fetchApex();
      }

      // Fetch history (firebase images) if missing, stale, or forced
      if (forceRefresh || _historyCache == null || shouldRefreshHistory()) {
        await _fetchFirebaseImages();
        // Update history cache and timestamp
        _historyCache = List<Map<String, dynamic>>.from(_imageFiles);
        _historyLastFetch = DateTime.now();
        
        // Preload images after successful fetch
        _preloadImagesInBackground();
      }

      // Set apex cache if not already set
      if (_apexCache == null) {
        _apexCache = List<Map<String, dynamic>>.from(_apexItems);
        _apexLastFetch = DateTime.now();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ DataProvider fetch error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Public refresh method for pull-to-refresh
  Future<void> refresh() async => fetchData(forceRefresh: true);

  /// Force refresh history (used by UI pull-to-refresh)
  Future<void> forceRefreshHistory() async {
    await fetchData(forceRefresh: true);
  }

  Future<void> _fetchApex() async {
    final apexUrl = Uri.parse('https://oracleapex.com/ords/g3_data/crop-vision/crop_g5/');
    try {
      final resp = await http.get(apexUrl).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final apexJson = json.decode(resp.body) as Map<String, dynamic>?;
        final items = apexJson?['items'] ?? apexJson?['rows'] ?? apexJson?['data'];
        if (items is List) {
          _apexItems = items.whereType<Map<String, dynamic>>().toList();
          // Update apex cache + timestamp
          _apexCache = List<Map<String, dynamic>>.from(_apexItems);
          _apexLastFetch = DateTime.now();
          if (kDebugMode) debugPrint('✅ Fetched ${_apexItems.length} APEX items');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to fetch APEX metadata: $e');
      // Keep existing apexCache if available
    }
  }

  Future<void> _fetchFirebaseImages() async {
    final storageRef = FirebaseStorage.instance.ref().child('crops');
    final listResult = await storageRef.listAll();
    final files = <Map<String, dynamic>>[];

    // Build a lookup from apex items to reduce nested loop cost
    final apexById = <String, Map<String, dynamic>>{};
    for (final meta in (_apexCache ?? _apexItems)) {
      final id = (meta['crop_id'] ?? meta['id'])?.toString();
      if (id != null) apexById[id] = meta;
    }

    const int concurrency = 6;
    final items = List<Reference>.from(listResult.items);
    
    for (int offset = 0; offset < items.length; offset += concurrency) {
      final batch = items.sublist(offset, min(offset + concurrency, items.length));
      final futures = batch.map((item) async {
        try {
          final meta = await item.getMetadata();
          final url = await item.getDownloadURL();

          // Match apex metadata if available
          Map<String, dynamic>? matched;
          
          // Try id-based match first (fastest)
          for (final id in apexById.keys) {
            if (item.name.contains(id)) {
              matched = apexById[id];
              break;
            }
          }
          
          // Fallback to url matching if not found
          if (matched == null) {
            for (final metaEntry in (_apexCache ?? _apexItems)) {
              final metaUrl = (metaEntry['image_url'] ?? metaEntry['url'])?.toString();
              if (metaUrl != null && url.contains(metaUrl.split('/').last)) {
                matched = metaEntry;
                break;
              }
              if (metaUrl != null && metaUrl == url) {
                matched = metaEntry;
                break;
              }
            }
          }

          return {
            'name': item.name,
            'url': url,
            'meta': matched,
            'timeCreated': meta.timeCreated,
          };
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Failed to fetch URL for ${item.name}: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      for (final r in results) {
        if (r != null) files.add(r);
      }

      // Update _imageFiles progressively so UI can show images early
      _imageFiles = List<Map<String, dynamic>>.from(files);
      notifyListeners();
    }

    // Final assignment (already updated progressively)
    _imageFiles = files;
    if (kDebugMode) debugPrint('✅ Fetched ${files.length} Firebase images');
  }

  bool shouldRefreshHistory({Duration maxAge = const Duration(minutes: 7)}) {
    if (_historyLastFetch == null) return true;
    return DateTime.now().difference(_historyLastFetch!) > maxAge;
  }

  bool shouldRefreshApex({Duration maxAge = const Duration(minutes: 20)}) {
    if (_apexLastFetch == null) return true;
    return DateTime.now().difference(_apexLastFetch!) > maxAge;
  }

  /// Preload images into cache in background (improved batching)
  void _preloadImagesInBackground() async {
    if (_isPreloading || _imageFiles.isEmpty) return;
    
    _isPreloading = true;
    notifyListeners();

    try {
      if (kDebugMode) debugPrint('📥 Starting preload of ${_imageFiles.length} images...');
      
      // Extract all valid URLs
      final urls = _imageFiles
          .map((f) => f['url'] as String?)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

      // Preload in batches to avoid overwhelming the system
      const batchSize = 5;
      int loaded = 0;
      int skipped = 0;

      for (int i = 0; i < urls.length; i += batchSize) {
        final batch = urls.sublist(i, min(i + batchSize, urls.length));
        
        final results = await Future.wait(
          batch.map((url) => _preloadSingleImage(url)),
          eagerError: false,
        );

        for (final result in results) {
          if (result == true) {
            loaded++;
          } else if (result == null) {
            skipped++;
          }
        }

        if (kDebugMode && (i + batchSize) % 20 == 0) {
          debugPrint('📥 Progress: $loaded loaded, $skipped cached, ${i + batchSize}/${urls.length} processed');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Preload complete: $loaded new, $skipped already cached, ${urls.length} total');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error during preload: $e');
    } finally {
      _isPreloading = false;
      notifyListeners();
    }
  }

  /// Preload a single image. Returns true if downloaded, null if already cached, false if failed.
  Future<bool?> _preloadSingleImage(String url) async {
    try {
      // Check if already cached
      final fileInfo = await FirebaseImageCacheManager.instance.getFileFromCache(url);
      if (fileInfo != null) {
        return null; // Already cached
      }

      // Download and cache
      await FirebaseImageCacheManager.instance.downloadFile(url);
      return true; // Successfully downloaded
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to preload $url: $e');
      return false; // Failed
    }
  }

  /// Legacy method for compatibility - now uses improved preloading
  @Deprecated('Use _preloadImagesInBackground instead')
  void _prefetchImages() {
    _preloadImagesInBackground();
  }

  /// Clear all caches and force refresh
  Future<void> clearCacheAndRefresh() async {
    await FirebaseImageCacheManager.clearCache();
    _historyCache = null;
    _apexCache = null;
    _historyLastFetch = null;
    _apexLastFetch = null;
    await fetchData(forceRefresh: true);
  }
}