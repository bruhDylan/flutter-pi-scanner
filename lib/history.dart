import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// Fetch all image files from the `crops` folder in Firebase Storage
  Future<List<Map<String, String>>> _fetchStorageImages() async {
    final storageRef = FirebaseStorage.instance.ref().child('crops');
    final listResult = await storageRef.listAll();

    final files = <Map<String, String>>[];
    for (final item in listResult.items) {
      try {
        final url = await item.getDownloadURL();

        // ✅ Keep .firebasestorage.app intact — this is your real bucket
        debugPrint("🖼️ Loaded image: $url");

        files.add({
          'name': item.name,
          'url': url,
        });
      } catch (e) {
        debugPrint("⚠️ Failed to fetch URL for ${item.name}: $e");
      }
    }
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text(
          'Scan History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF41)),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _fetchStorageImages(),
        builder: (context, snapshot) {
          // ⏳ Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF41)),
            );
          }

          // ❌ Error state
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading images:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final files = snapshot.data ?? [];

          // 📭 No data
          if (files.isEmpty) {
            return const Center(
              child: Text(
                'No scans found in Firebase Storage.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // ✅ Success — build the list
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageDetailPage(
                        name: file['name']!,
                        url: file['url']!,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FF41).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: SizedBox(
                      width: 60,
                      height: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          file['url']!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF00FF41),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF0A0E27),
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      file['name']!,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF00FF41),
                      size: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Fullscreen image viewer
class ImageDetailPage extends StatelessWidget {
  final String name;
  final String url;

  const ImageDetailPage({super.key, required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    // ✅ Keep URL as-is (.firebasestorage.app)
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.8,
          maxScale: 3.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00FF41),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
