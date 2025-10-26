import 'package:flutter/material.dart';
import 'dart:math' as math;

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
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final avgConfidence =
        mockScans.fold<double>(0, (sum, s) => sum + s.confidence) /
            mockScans.length;
    final totalScans = mockScans.length;
    final recentScans = mockScans
        .where((s) =>
            s.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF00FF41)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(totalScans, avgConfidence, recentScans),
            const SizedBox(height: 24),
            _buildGraphSection(),
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
                    color: Color(0xFF00FF41),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...mockScans.map((scan) => _buildScanCard(context, scan)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF00FF41),
        child: const Icon(Icons.add_a_photo, color: Color(0xFF0A0E27)),
      ),
    );
  }

  Widget _buildStatsSection(int total, double avg, int recent) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.scanner,
            label: "Total Scans",
            value: total.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            label: "Avg Confidence",
            value: "${avg.toStringAsFixed(1)}%",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            label: "This Week",
            value: recent.toString(),
          ),
        ),
      ],
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
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFED8405).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFED8405), size: 24),
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
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphSection() => InteractiveGraph(scans: mockScans);

  Widget _buildScanCard(BuildContext context, Scan scan) {
    final timeAgo = _formatTimeAgo(scan.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFED8405).withOpacity(0.15),
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
                      color: const Color(0xFFED8405).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.bug_report,
                      color: Color(0xFFED8405), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scan.disease,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _getConfidenceColor(scan.confidence)
                                      .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${scan.confidence.toInt()}% confidence",
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _getConfidenceColor(scan.confidence),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(timeAgo,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: const Color(0xFFED8405).withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSheet(Scan scan) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(scan.disease,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 16),
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFED8405).withOpacity(0.3),
                      width: 1.5),
                ),
                child: const Center(
                    child: Icon(Icons.image_outlined,
                        size: 60, color: Color(0xFFED8405))),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Text("Confidence:",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: scan.confidence / 100,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFED8405),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Text("${scan.confidence.toInt()}%",
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFED8405),
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              const Text("Recommendations",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 12),
              ...scan.recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFED8405).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.check,
                              color: Color(0xFFED8405), size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(rec,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

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
}

/// ===== GRAPH WIDGET =====
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
    final sorted = List<Scan>.from(widget.scans)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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
