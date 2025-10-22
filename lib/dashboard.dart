import 'package:flutter/material.dart';
import 'dart:math' as math;

// Mock scan model
class Scan {
  final String disease;
  final double confidence;
  final DateTime timestamp;
  final List<String> recommendations;

  Scan({
    required this.disease,
    required this.confidence,
    required this.timestamp,
    required this.recommendations,
  });
}

// Mock data
final List<Scan> mockScans = [
  Scan(
    disease: "Apple Scab",
    confidence: 92,
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    recommendations: ["Remove infected leaves", "Apply fungicide X"],
  ),
  Scan(
    disease: "Powdery Mildew",
    confidence: 85,
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    recommendations: ["Spray sulfur-based fungicide", "Remove infected parts"],
  ),
  Scan(
    disease: "Blotch Spot",
    confidence: 78,
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    recommendations: ["Apply recommended pesticide", "Prune affected branches"],
  ),
  Scan(
    disease: "Fire Blight",
    confidence: 88,
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
    recommendations: ["Prune infected areas", "Disinfect tools"],
  ),
  Scan(
    disease: "Leaf Rust",
    confidence: 81,
    timestamp: DateTime.now().subtract(const Duration(days: 5)),
    recommendations: ["Apply copper fungicide", "Improve air circulation"],
  ),
];

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final avgConfidence = mockScans.fold<double>(
            0, (sum, scan) => sum + scan.confidence) /
        mockScans.length;
    final totalScans = mockScans.length;
    final recentScans = mockScans.where((s) => 
      s.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))
    ).length;

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
            // Stats Overview
            _buildStatsSection(totalScans, avgConfidence, recentScans),
            const SizedBox(height: 24),
            
            // Graph Section
            _buildGraphSection(),
            const SizedBox(height: 24),
            
            // Recent Scans Header
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
            
            // Scans List
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

  Widget _buildGraphSection() {
    return InteractiveGraph(scans: mockScans);
  }

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
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _buildDetailSheet(scan),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Disease Icon/Image placeholder
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
                  child: const Icon(
                    Icons.bug_report,
                    color: Color(0xFFED8405),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Disease info
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getConfidenceColor(scan.confidence)
                                  .withOpacity(0.2),
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
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFFED8405).withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSheet(Scan scan) {
    return Container(
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
            // Handle bar
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
            
            // Title
            Text(
              scan.disease,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // Image placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E27),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFED8405).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 60,
                  color: Color(0xFFED8405),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Confidence bar
            Row(
              children: [
                const Text(
                  "Confidence:",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    children: [
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${scan.confidence.toInt()}%",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFED8405),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recommendations
            const Text(
              "Recommendations",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
                          color: const Color(0xFFED8405).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFFED8405),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rec,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 85) return const Color(0xFFED8405);
    if (confidence >= 70) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}

// Custom painter for confidence graph
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final dotPaint = Paint()
      ..color = const Color(0xFFED8405)
      ..style = PaintingStyle.fill;

    // Sort scans by timestamp
    final sortedScans = List<Scan>.from(scans)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    // Calculate points
    for (int i = 0; i < sortedScans.length; i++) {
      final x = (i / (sortedScans.length - 1)) * size.width;
      final y = size.height - (sortedScans[i].confidence / 100 * size.height);
      points.add(Offset(x, y));
    }

    // Draw fill area
    if (points.isNotEmpty) {
      fillPath.moveTo(points.first.dx, size.height);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, paint);
    }

    // Draw line
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw dots
    for (int i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      canvas.drawCircle(
        points[i],
        isHovered ? 6 : 4,
        dotPaint,
      );
      
      // Draw outer ring for hovered point
      if (isHovered) {
        final ringPaint = Paint()
          ..color = const Color(0xFFED8405).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(points[i], 10, ringPaint);
      }
    }

    // Draw grid lines with percentage labels
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final y = (i / 4) * size.height;
      final percentage = 100 - (i * 25);
      
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Draw percentage label
      textPainter.text = TextSpan(
        text: '$percentage%',
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 10,
          fontFamily: 'SF Pro Text',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-30, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant ConfidenceGraphPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex;
  }
}

// Interactive graph widget
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
    final sortedScans = List<Scan>.from(widget.scans)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FF41).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Confidence Trend",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (hoveredIndex != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF41).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sortedScans[hoveredIndex!].disease,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00FF41),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          MouseRegion(
            onHover: (event) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(event.position);
              final graphWidth = box.size.width - 40; // Account for padding
              final graphHeight = 150.0;
              
              // Calculate which point is being hovered
              if (localPosition.dy >= 56 && localPosition.dy <= 56 + graphHeight) {
                final relativeX = (localPosition.dx - 20).clamp(0.0, graphWidth);
                final normalizedX = relativeX / graphWidth;
                final index = (normalizedX * (sortedScans.length - 1)).round()
                    .clamp(0, sortedScans.length - 1);
                
                setState(() {
                  hoverPosition = localPosition;
                  hoveredIndex = index;
                });
              }
            },
            onExit: (_) {
              setState(() {
                hoverPosition = null;
                hoveredIndex = null;
              });
            },
            child: SizedBox(
              height: 150,
              child: Stack(
                children: [
                  Positioned(
                    left: 30,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: CustomPaint(
                      painter: ConfidenceGraphPainter(
                        widget.scans,
                        hoverPosition: hoverPosition,
                        hoveredIndex: hoveredIndex,
                      ),
                      size: const Size(double.infinity, 150),
                    ),
                  ),
                  // Tooltip
                  if (hoveredIndex != null && hoverPosition != null)
                    Positioned(
                      left: hoverPosition!.dx - 60,
                      top: hoverPosition!.dy - 80,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E27),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00FF41).withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF41).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sortedScans[hoveredIndex!].disease,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${sortedScans[hoveredIndex!].confidence.toInt()}% confidence',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF00FF41),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}