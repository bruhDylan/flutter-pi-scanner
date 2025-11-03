import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalyticsResult {
  final int total;
  final double avgConfidence;
  final int recent;
  final List<Map<String, dynamic>> recentItems;

  AnalyticsResult({required this.total, required this.avgConfidence, required this.recent, required this.recentItems});
}

/// Fetch analytics from the Oracle APEX endpoint and return aggregated metrics.
Future<AnalyticsResult> fetchAnalyticsFromApex({Duration timeout = const Duration(seconds: 10)}) async {
  final url = Uri.parse('https://oracleapex.com/ords/g3_data/crop-vision/crop_g5/');
  try {
    final resp = await http.get(url).timeout(timeout);
    if (resp.statusCode != 200) {
      return AnalyticsResult(total: 0, avgConfidence: 0, recent: 0, recentItems: []);
    }

    final jsonBody = json.decode(resp.body) as Map<String, dynamic>?;
    if (jsonBody == null) return AnalyticsResult(total: 0, avgConfidence: 0, recent: 0, recentItems: []);

    final items = (jsonBody['items'] ?? jsonBody['rows'] ?? jsonBody['data']) as List<dynamic>? ?? [];

    final parsed = <Map<String, dynamic>>[];
    double sum = 0;
    int countConfidence = 0;
    for (final it in items) {
      if (it is Map<String, dynamic>) {
        parsed.add(it);
        final confRaw = it['confidence']?.toString();
        if (confRaw != null) {
          try {
            final d = double.parse(confRaw);
            sum += d;
            countConfidence++;
          } catch (_) {}
        }
      }
    }

    final total = parsed.length;
    final avg = countConfidence > 0 ? (sum / countConfidence) : 0.0;

    // "recent" cannot be derived reliably if API doesn't include timestamps; fall back to total
    final recent = total;

    return AnalyticsResult(total: total, avgConfidence: avg, recent: recent, recentItems: parsed);
  } catch (e) {
    return AnalyticsResult(total: 0, avgConfidence: 0, recent: 0, recentItems: []);
  }
}

/// Fetch group 8 sensor data (temperature and moisture) from APEX
Future<List<Map<String, dynamic>>> fetchGroup8Data({Duration timeout = const Duration(seconds: 10)}) async {
  final url = Uri.parse('https://oracleapex.com/ords/g3_data/groups/data/8');
  try {
    final resp = await http.get(url).timeout(timeout);
    if (resp.statusCode != 200) return [];

    final jsonBody = json.decode(resp.body) as Map<String, dynamic>?;
    if (jsonBody == null) return [];

    final items = (jsonBody['items'] ?? jsonBody['rows'] ?? jsonBody['data']) as List<dynamic>? ?? [];
    final parsed = <Map<String, dynamic>>[];
    for (final it in items) {
      if (it is Map<String, dynamic>) {
        // Parse fields we care about
        final tempRaw = it['temperature'] ?? it['temp'];
        final moistureRaw = it['moisture'];
        final tsRaw = it['corrected_created_at'] ?? it['created_at'] ?? it['timestamp'];

        double? temp;
        double? moisture;
        DateTime? ts;

        if (tempRaw != null) {
          try {
            temp = double.parse(tempRaw.toString());
          } catch (_) {}
        }
        if (moistureRaw != null) {
          try {
            moisture = double.parse(moistureRaw.toString());
          } catch (_) {}
        }
        if (tsRaw != null) {
          try {
            // Parse format like '30-OCT-2025 13:54:48'
            final s = tsRaw.toString();
            ts = _parseApexDate(s) ?? DateTime.now();
          } catch (_) {
            ts = DateTime.now();
          }
        } else {
          ts = DateTime.now();
        }

        parsed.add({'timestamp': ts, 'temperature': temp ?? 0.0, 'moisture': moisture ?? 0.0});
      }
    }

    // sort ascending by timestamp
    parsed.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
    return parsed;
  } catch (e) {
    return [];
  }
}

/// Parse dates like '30-OCT-2025 13:54:48'
DateTime? _parseApexDate(String s) {
  try {
    // split date and time
    final parts = s.split(' ');
    if (parts.length < 2) return null;
    final datePart = parts[0]; // 30-OCT-2025
    final timePart = parts.sublist(1).join(' '); // 13:54:48

    final dateParts = datePart.split('-');
    if (dateParts.length != 3) return null;
    final day = int.tryParse(dateParts[0]);
    final monthStr = dateParts[1].toUpperCase();
    final year = int.tryParse(dateParts[2]);
    if (day == null || year == null) return null;

    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12,
    };
    final month = months[monthStr] ?? 1;

    final timeParts = timePart.split(':');
    final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '0') ?? 0;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
    final second = int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;

    return DateTime(year, month, day, hour, minute, second);
  } catch (_) {
    return null;
  }
}
