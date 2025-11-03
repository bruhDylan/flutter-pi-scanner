import 'dart:math';
import 'package:flutter/material.dart';
import 'dashboard.dart' show Scan;
import 'widgets/scan_detail_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';
import 'services/firebase_image_cache_manager.dart';

// Theme tokens
const Color kLightBlue = Color(0xFF9198E5);
const Color kDarkCardBg = Color(0xFF0B1220);
const Color kPageBg = Color(0xFF0F1724);

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with AutomaticKeepAliveClientMixin {
  bool _isGrid = false;
  bool _sortAscending = true;
  int _timeFilter = 0; // 0=All, 1=30d, 2=7d, 3=24h

  void _toggleView() => setState(() => _isGrid = !_isGrid);

  void _toggleSort() => setState(() => _sortAscending = !_sortAscending);

  void _refresh() async {
    final prov = Provider.of<DataProvider>(context, listen: false);
    await prov.forceRefreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kPageBg,
        elevation: 0,
        title: const Text(
          'Scan History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view, color: Colors.white),
            onPressed: _toggleView,
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            onPressed: _toggleSort,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, __) {
          return RefreshIndicator(
            onRefresh: () async {
              await provider.forceRefreshHistory();
            },
            child: Builder(builder: (ctx) {
              final files = provider.historyCache ?? [];
              final isLoading = provider.isLoading;
              final isPreloading = provider.isPreloading;

              // Show spinner if no cached data and loading
              if (files.isEmpty && isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (files.isEmpty) {
                return const Center(
                  child: Text(
                    'No scans found in Firebase Storage.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              // Filter by time window
              final now = DateTime.now();
              Duration? window;
              if (_timeFilter == 1) window = const Duration(days: 30);
              if (_timeFilter == 2) window = const Duration(days: 7);
              if (_timeFilter == 3) window = const Duration(hours: 24);

              final filtered = files.where((f) {
                final dynamic rawTs = f['timeCreated'];
                final ts = _toDateTime(rawTs);
                if (ts == null) return true;
                if (window == null) return true;
                return ts.isAfter(now.subtract(window));
              }).toList();

              // Sort
              final displayFiles = List<Map<String, dynamic>>.from(filtered);
              displayFiles.sort((a, b) {
                final aTime = _toDateTime(a['timeCreated']) ?? DateTime(2000);
                final bTime = _toDateTime(b['timeCreated']) ?? DateTime(2000);
                return _sortAscending
                    ? aTime.compareTo(bTime)
                    : bTime.compareTo(aTime);
              });

              // Time filter buttons
              final filterButtons = ToggleButtons(
                isSelected: [
                  _timeFilter == 0,
                  _timeFilter == 1,
                  _timeFilter == 2,
                  _timeFilter == 3
                ],
                onPressed: (i) => setState(() => _timeFilter = i),
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
                children: const [
                  Text('All'),
                  Text('30d'),
                  Text('7d'),
                  Text('24h')
                ],
              );

              return Column(
                children: [
                  // Filter controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: filterButtons),
                        if (isPreloading) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Caching...',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: _isGrid
                        ? _buildGridView(displayFiles)
                        : _buildListView(displayFiles, isLoading),
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> displayFiles) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900
            ? 6
            : MediaQuery.of(context).size.width > 600
                ? 4
                : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: displayFiles.length,
      itemBuilder: (context, index) {
        final f = displayFiles[index];
        final meta = f['meta'] as Map<String, dynamic>?;
        final scan = Scan(
          imageUrl: f['url'] ?? '',
          disease: meta != null ? (meta['label'] ?? 'Unknown') : f['name'] ?? 'Scan',
          confidence: meta != null
              ? (double.tryParse(
                      (meta['confidence'] ?? meta['score'] ?? '').toString()) ??
                  0.0)
              : 0.0,
          timestamp: _toDateTime(f['timeCreated']) ?? DateTime.now(),
          recommendations: meta != null
              ? List<String>.from((meta['recommendation'] is List)
                  ? meta['recommendation']
                  : [meta['recommendation'] ?? ''])
              : ['No recommendations'],
        );

        return _buildGridTile(context, scan, f);
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> displayFiles, bool isLoading) {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: displayFiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final f = displayFiles[index];
            final meta = f['meta'] as Map<String, dynamic>?;
            final scan = Scan(
              imageUrl: f['url'] ?? '',
              disease: meta != null ? (meta['label'] ?? 'Unknown') : f['name'] ?? 'Scan',
              confidence: meta != null
                  ? (double.tryParse(
                          (meta['confidence'] ?? meta['score'] ?? '').toString()) ??
                      0.0)
                  : 0.0,
              timestamp: _toDateTime(f['timeCreated']) ?? DateTime.now(),
              recommendations: meta != null
                  ? List<String>.from((meta['recommendation'] is List)
                      ? meta['recommendation']
                      : [meta['recommendation'] ?? ''])
                  : ['No recommendations'],
            );

            return _buildHistoryCardRow(context, scan, f);
          },
        ),
        if (isLoading)
          Positioned(
            right: 24,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Refreshing',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGridTile(BuildContext context, Scan scan, Map<String, dynamic> raw) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ScanDetailSheet(scan: scan),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kDarkCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLightBlue.withOpacity(0.06), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: scan.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: scan.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 300, // Memory optimization
                  memCacheHeight: 300,
                  cacheManager: FirebaseImageCacheManager.instance,
                  placeholder: (context, url) => Container(
                    color: kDarkCardBg,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kLightBlue,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildHistoryCardRow(BuildContext context, Scan scan, Map<String, dynamic> raw) {
    final timeAgo = _formatDateTime(scan.timestamp);
    return Container(
      decoration: BoxDecoration(
        color: kDarkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLightBlue.withOpacity(0.12), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => ScanDetailSheet(scan: scan),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kLightBlue.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: scan.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: scan.imageUrl,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            memCacheWidth: 150, // Memory optimization
                            memCacheHeight: 150,
                            cacheManager: FirebaseImageCacheManager.instance,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kLightBlue,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error, color: Colors.grey),
                          )
                        : const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.disease,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getConfidenceColor(scan.confidence)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${scan.confidence.toInt()}% confidence",
                              style: TextStyle(
                                fontSize: 12,
                                color: _getConfidenceColor(scan.confidence),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: kLightBlue.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double c) {
    if (c >= 85) return const Color(0xFFED8405);
    if (c >= 70) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  DateTime? _toDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        try {
          return DateTime.parse(raw.replaceAll(' ', 'T'));
        } catch (_) {
          return null;
        }
      }
    }
    if (raw is Map) {
      if (raw['seconds'] != null) {
        final secs = raw['seconds'];
        try {
          return DateTime.fromMillisecondsSinceEpoch(
            (secs is int) ? secs * 1000 : int.parse(secs.toString()) * 1000,
          );
        } catch (_) {
          return null;
        }
      }
      if (raw['_seconds'] != null) {
        final secs = raw['_seconds'];
        try {
          return DateTime.fromMillisecondsSinceEpoch(
            (secs is int) ? secs * 1000 : int.parse(secs.toString()) * 1000,
          );
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<DataProvider>(context, listen: false);
      // Fetch data and then preload images
      prov.fetchDataIfNeeded();
    });
  }
}