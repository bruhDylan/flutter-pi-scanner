import 'package:flutter/material.dart';
import 'services/analytics_service.dart';
import 'widgets/scan_detail_sheet.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';

// Theme colors (consistent across dashboard)
const Color kLightBlue = Color(0xFF9198E5);
const Color kDarkCardBg = Color(0xFF0B1220); // used for stat cards and recent scans
const Color kPageBg = Color(0xFF0F1724); // rgba(15,23,36) page background

// Top-level painter for line chart
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool showTemp;
  LineChartPainter(this.data, {required this.showTemp});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 1.0;
    final axisPaint = Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 1.2;

    final paddingLeft = 30.0;
    final paddingBottom = 20.0;
    final chartWidth = size.width - paddingLeft - 8;
    final chartHeight = size.height - paddingBottom - 8;

    // Draw horizontal grid lines and y-axis ticks
    final ys = 4; // number of y ticks
    for (int i = 0; i <= ys; i++) {
      final y = 8 + (chartHeight * i / ys);
      canvas.drawLine(Offset(paddingLeft, y), Offset(paddingLeft + chartWidth, y), gridPaint);
    }

    final points = data;
    if (points.isEmpty) return;

    double minV = double.infinity, maxV = -double.infinity;
    for (final p in points) {
      final v = (showTemp ? (p['temperature'] as double? ?? 0.0) : (p['moisture'] as double? ?? 0.0));
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (minV == maxV) {
      minV = minV - 1;
      maxV = maxV + 1;
    }

    // Draw y-axis labels
    final textStyle = TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10);
    for (int i = 0; i <= ys; i++) {
      final v = maxV - (i * (maxV - minV) / ys);
      final y = 8 + (chartHeight * i / ys);
      final tp = TextPainter(text: TextSpan(text: v.toStringAsFixed(0), style: textStyle), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(4, y - tp.height / 2));
    }

    // Map data to points and draw line
    final stepX = chartWidth / (points.length - 1);
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final v = (showTemp ? (points[i]['temperature'] as double? ?? 0.0) : (points[i]['moisture'] as double? ?? 0.0));
      final x = paddingLeft + stepX * i;
      final y = 8 + ((maxV - v) / (maxV - minV)) * chartHeight;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    final linePaint = Paint()
      ..color = showTemp ? Colors.orange.shade400 : Colors.indigo.shade500
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Draw points
    final dotPaint = Paint()..color = showTemp ? Colors.orange.shade400 : Colors.indigo.shade500;
    for (int i = 0; i < points.length; i++) {
      final v = (showTemp ? (points[i]['temperature'] as double? ?? 0.0) : (points[i]['moisture'] as double? ?? 0.0));
      final x = paddingLeft + stepX * i;
      final y = 8 + ((maxV - v) / (maxV - minV)) * chartHeight;
      canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
    }

    // Draw x-axis
    canvas.drawLine(Offset(paddingLeft, 8 + chartHeight), Offset(paddingLeft + chartWidth, 8 + chartHeight), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ===== SCAN MODEL =====
class Scan {
  final String imageUrl;
  final String disease;
  final double confidence;
  final DateTime timestamp;
  final List<String> recommendations;

  Scan({
    required this.imageUrl,
    required this.disease,
    required this.confidence,
    required this.timestamp,
    required this.recommendations,
  });
}

/// ===== MOCK DATA =====
final List<Scan> mockScans = [
  Scan(
    imageUrl: '', // 🔸 you can later replace with Firebase Storage URLs
    disease: "Apple Scab",
    confidence: 92,
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    recommendations: ["Remove infected leaves", "Apply fungicide X"],
  ),
  Scan(
    imageUrl: '',
    disease: "Powdery Mildew",
    confidence: 85,
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    recommendations: ["Spray sulfur-based fungicide", "Remove infected parts"],
  ),
  Scan(
    imageUrl: '',
    disease: "Blotch Spot",
    confidence: 78,
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    recommendations: ["Apply recommended pesticide", "Prune affected branches"],
  ),
  Scan(
    imageUrl: '',
    disease: "Fire Blight",
    confidence: 88,
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
    recommendations: ["Prune infected areas", "Disinfect tools"],
  ),
  Scan(
    imageUrl: '',
    disease: "Leaf Rust",
    confidence: 81,
    timestamp: DateTime.now().subtract(const Duration(days: 5)),
    recommendations: ["Apply copper fungicide", "Improve air circulation"],
  ),
];

/// ===== DASHBOARD PAGE =====
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  int _total = 0;
  double _avg = 0.0;
  int _recent = 0;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _group8Data = [];
  bool _showTemperature = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await fetchAnalyticsFromApex();
    final groupData = await fetchGroup8Data();
    if (res.total == 0 && res.avgConfidence == 0 && res.recent == 0) {
      // fallback to mock data
      final avgConfidence = mockScans.fold<double>(0, (sum, s) => sum + s.confidence) / mockScans.length;
      if (!mounted) return;
      setState(() {
        _total = mockScans.length;
        _avg = avgConfidence;
        _recent = mockScans.where((s) => s.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length;
        _items = [];
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _total = res.total;
      _avg = res.avgConfidence;
      _recent = res.recent;
      _items = res.recentItems;
  _group8Data = groupData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
  final prov = Provider.of<DataProvider>(context);
  final totalScans = prov.imageFiles.isNotEmpty ? prov.imageFiles.length : (_loading ? mockScans.length : _total);
    final avgConfidence = _loading ? mockScans.fold<double>(0, (sum, s) => sum + s.confidence) / mockScans.length : _avg;
    final recentScans = _loading ? mockScans.where((s) => s.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length : _recent;
  final recentItemsCount = _items.length;

    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
          backgroundColor: kPageBg,
          elevation: 0,
          title: const Text("Dashboard", style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAnalytics,
            ),
          ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsCard(totalScans, avgConfidence, recentScans),
              const SizedBox(height: 18),
              // small stats row using the stat card helper to avoid analyzer unused warnings
              Row(
                children: [
                  Expanded(child: _buildStatCard(icon: Icons.scanner, label: 'Total Scans', value: totalScans.toString())),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(icon: Icons.trending_up, label: 'Avg Confidence', value: '${avgConfidence.toStringAsFixed(1)}%')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(icon: Icons.calendar_today, label: 'This Week', value: recentItemsCount.toString())),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Scans",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "$totalScans total",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Show 5 most recent scans from Firebase if available, fallback to mock
              Builder(builder: (ctx) {
                final prov = Provider.of<DataProvider>(ctx);
                final files = prov.historyCache ?? [];
                if (files.isNotEmpty) {
                  // sort by timeCreated (newest first)
                  final items = List<Map<String, dynamic>>.from(files);
                  items.sort((a, b) {
                    final at = a['timeCreated'];
                    final bt = b['timeCreated'];
                    DateTime da = at is DateTime ? at : (at is String ? DateTime.tryParse(at) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
                    DateTime db = bt is DateTime ? bt : (bt is String ? DateTime.tryParse(bt) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
                    return db.compareTo(da);
                  });

                  final recent = items.take(5).map((f) {
                    final meta = f['meta'] as Map<String, dynamic>?;
                    return Scan(
                      imageUrl: f['url'] ?? '',
                      disease: meta != null ? (meta['label'] ?? 'Unknown') : (f['name'] ?? 'Scan'),
                      confidence: meta != null ? (double.tryParse((meta['confidence'] ?? meta['score'] ?? '').toString()) ?? 0.0) : 0.0,
                      timestamp: f['timeCreated'] is DateTime ? f['timeCreated'] as DateTime : DateTime.now(),
                      recommendations: meta != null ? List<String>.from((meta['recommendation'] is List) ? meta['recommendation'] : [meta['recommendation'] ?? '']) : ['No recommendations'],
                    );
                  }).toList();

                  return Column(children: recent.map((scan) => _buildScanCard(context, scan)).toList());
                }
                // fallback to mock scans
                return Column(children: mockScans.map((scan) => _buildScanCard(context, scan)).toList());
              }),
            ],
          ),
        ),
      ),
  // removed camera FAB per request
    );
  }
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kLightBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(int total, double avg, int recent) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1724),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // gradient glow
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade500.withOpacity(0.12), Colors.purple.shade400.withOpacity(0.08), Colors.pink.shade400.withOpacity(0.06)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
                // inner card
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220),
                    borderRadius: BorderRadius.circular(11),
                  ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [Colors.indigo.shade500, Colors.purple.shade400],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(Icons.analytics, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              const Text('Performance Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                const Text('Live', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF0F1724).withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Total Scans', style: TextStyle(color: Color.from(alpha: 1, red: 0.62, green: 0.62, blue: 0.62), fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(total.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text('+12.3%', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF0F1724).withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Average', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('${avg.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text('+8.1%', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // live line chart (toggle temperature / moisture)
                      // increase available height so axis labels and numbers
                      // aren't cramped and to reduce risk of RenderFlex overflow
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildLineChart(_group8Data, showTemp: _showTemperature),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            // toggle button only
                            ToggleButtons(
                              isSelected: [_showTemperature, !_showTemperature],
                              onPressed: (i) {
                                setState(() {
                                  _showTemperature = i == 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              selectedColor: Colors.white,
                              fillColor: Colors.indigo.shade500,
                              color: Colors.white70,
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 28),
                              children: const [Text('Temp'), Text('Moist')],
                            )
                          ]),
                        ],
                      )
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context, Scan scan) {
    final timeAgo = _formatTimeAgo(scan.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kDarkCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kLightBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _buildDetailSheet(scan),
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
                  child: Icon(Icons.bug_report, color: kLightBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.disease,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getConfidenceColor(scan.confidence).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${scan.confidence.toInt()}% confidence",
                              style: TextStyle(fontSize: 12, color: _getConfidenceColor(scan.confidence), fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
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

  Widget _buildDetailSheet(Scan scan) => ScanDetailSheet(scan: scan);

  Color _getConfidenceColor(double c) {
    if (c >= 85) return const Color(0xFFED8405);
    if (c >= 70) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  String _formatTimeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Widget _buildLineChart(List<Map<String, dynamic>> data, {required bool showTemp}) {
    final points = data.isEmpty ? [] : List<Map<String, dynamic>>.from(data);
    final lastPoints = points.length > 7 ? points.sublist(points.length - 7) : points;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and legend
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(showTemp ? 'Temperature (°C)' : 'Moisture (%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('Live', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: LineChartWidget(data: List<Map<String, dynamic>>.from(lastPoints), showTemp: showTemp),
        ),
        const SizedBox(height: 8),
        // x-axis labels
        Builder(builder: (context) {
          final screenW = MediaQuery.of(context).size.width;
          final labelWidth = ((screenW - 200) / (lastPoints.isEmpty ? 1 : lastPoints.length)).clamp(40.0, 120.0);
          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: lastPoints.map((p) {
            final ts = p['timestamp'] as DateTime?;
            final label = ts != null ? '${ts.day}/${ts.month}' : '';
            return SizedBox(width: labelWidth, child: Center(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))));
          }).toList());
        }),
      ],
    );
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
 
}

/// ===== GRAPH WIDGET =====
/// Interactive wrapper for the LineChartPainter that handles hover/tap and shows a tooltip
class LineChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final bool showTemp;
  const LineChartWidget({super.key, required this.data, required this.showTemp});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  Offset? _hoverPos;
  Offset? _cursorPos;
  int? _hoverIndex;

  void _updateHover(Offset localPos, Size size) {
    final paddingLeft = 30.0;
    final chartWidth = size.width - paddingLeft - 8;
    final chartHeight = size.height - 20 - 8;
    final points = widget.data;
    if (points.isEmpty) return;

    _cursorPos = localPos;

    // compute min/max
    double minV = double.infinity, maxV = -double.infinity;
    for (final p in points) {
      final v = (widget.showTemp ? (p['temperature'] as double? ?? 0.0) : (p['moisture'] as double? ?? 0.0));
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (minV == maxV) { minV = minV - 1; maxV = maxV + 1; }

    final n = points.length;
    final stepX = n > 1 ? (chartWidth / (n - 1)) : 0.0;

    // build list of point positions
    final offsets = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = (widget.showTemp ? (points[i]['temperature'] as double? ?? 0.0) : (points[i]['moisture'] as double? ?? 0.0));
      final x = paddingLeft + (n > 1 ? stepX * i : chartWidth / 2);
      final y = 8 + ((maxV - v) / (maxV - minV)) * chartHeight;
      offsets.add(Offset(x, y));
    }

    // find nearest
    int nearest = 0;
    double best = double.infinity;
    for (int i = 0; i < offsets.length; i++) {
      final d = (offsets[i] - localPos).distance;
      if (d < best) { best = d; nearest = i; }
    }

    setState(() {
      _hoverIndex = nearest;
      _hoverPos = offsets[nearest];
      // cursor pos already set
    });
  }

  void _clearHover() {
    setState(() {
      _hoverIndex = null;
      _hoverPos = null;
    });
  }

  String _formatTs(DateTime ts) {
    return '${ts.year.toString().padLeft(4, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} '
           '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return MouseRegion(
        onHover: (ev) {
          final local = (context.findRenderObject() as RenderBox).globalToLocal(ev.position);
          _updateHover(local, size);
        },
        onExit: (_) => _clearHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (tap) {
            final local = (context.findRenderObject() as RenderBox).globalToLocal(tap.globalPosition);
            _updateHover(local, size);
          },
          onPanDown: (d) {
            final local = (context.findRenderObject() as RenderBox).globalToLocal(d.globalPosition);
            _updateHover(local, size);
          },
          child: Stack(children: [
            CustomPaint(painter: LineChartPainter(widget.data, showTemp: widget.showTemp), size: Size.infinite),
            // hover marker
            if (_hoverIndex != null && _hoverPos != null)
              Align(
                alignment: Alignment((_hoverPos!.dx / size.width) * 2 - 1, (_hoverPos!.dy / size.height) * 2 - 1),
                child: Transform.translate(
                  offset: Offset(-6, -6),
                  child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ),
            // tooltip positioned at cursor (cursor pos stored in _cursorPos)
            if (_cursorPos != null && _hoverIndex != null)
              Align(
                alignment: Alignment((_cursorPos!.dx / size.width) * 2 - 1, (_cursorPos!.dy / size.height) * 2 - 1),
                child: Transform.translate(
                  offset: Offset(8, -40),
                  child: Builder(builder: (ctx) {
                    final point = widget.data[_hoverIndex!];
                    final ts = point['timestamp'] as DateTime?;
                    final val = widget.showTemp ? (point['temperature'] as double? ?? 0.0) : (point['moisture'] as double? ?? 0.0);
                    final tooltipText = '${ts != null ? _formatTs(ts) : ''}\n${widget.showTemp ? 'Temp' : 'Moist'}: ${val.toStringAsFixed(1)}';
                    return Container(
                      padding: const EdgeInsets.all(8),
                      width: 140,
                      decoration: BoxDecoration(color: kDarkCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                      child: Text(tooltipText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    );
                  }),
                ),
              )
          ]),
        ),
      );
    });
  }
}

class ConfidenceGraphPainter extends CustomPainter {
  final List<Scan> scans;
  final Offset? hoverPosition;
  final int? hoveredIndex;
  ConfidenceGraphPainter(this.scans, {this.hoverPosition, this.hoveredIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (scans.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFFED8405).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFFED8405)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = const Color(0xFFED8405)
      ..style = PaintingStyle.fill;

    final sorted = List<Scan>.from(scans)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final points = <Offset>[];
    for (int i = 0; i < sorted.length; i++) {
      final x = (i / (sorted.length - 1)) * size.width;
      final y = size.height - (sorted[i].confidence / 100 * size.height);
      points.add(Offset(x, y));
    }

    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..addPolygon(points, false)
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, paint);

    final linePath = Path()..addPolygon(points, false);
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      canvas.drawCircle(points[i], isHovered ? 6 : 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConfidenceGraphPainter oldDelegate) =>
      oldDelegate.hoveredIndex != hoveredIndex;
}

class InteractiveGraph extends StatefulWidget {
  final List<Scan> scans;
  const InteractiveGraph({super.key, required this.scans});
  @override
  State<InteractiveGraph> createState() => _InteractiveGraphState();
}

class _InteractiveGraphState extends State<InteractiveGraph> {
  Offset? hoverPosition;
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
  // intentionally using widget.scans directly for the painter; no separate sorted needed here

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00FF41).withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Confidence Trend",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: ConfidenceGraphPainter(
                widget.scans,
                hoverPosition: hoverPosition,
                hoveredIndex: hoveredIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}