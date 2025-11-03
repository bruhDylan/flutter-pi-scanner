import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../dashboard.dart';
import '../services/firebase_image_cache_manager.dart';

class ScanDetailSheet extends StatelessWidget {
  final Scan scan;
  const ScanDetailSheet({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kDarkCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                border: Border.all(width: 1.5, color: kLightBlue.withOpacity(0.3)),
              ),
              child: scan.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: scan.imageUrl,
                      fit: BoxFit.cover,
                      cacheManager: FirebaseImageCacheManager.instance,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
                    )
                  : Center(child: Icon(Icons.image_outlined, size: 60, color: kLightBlue)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Text("Confidence:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
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
                        color: _getConfidenceColor(scan.confidence),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Text("${scan.confidence.toInt()}%", style: const TextStyle(fontSize: 16, color: Color(0xFFED8405), fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 24),
            const Text("Recommendations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        child: Icon(Icons.check, color: kLightBlue, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(rec, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double c) {
    if (c >= 85) return const Color(0xFFED8405);
    if (c >= 70) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }
}
