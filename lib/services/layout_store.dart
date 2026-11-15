import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers where the user dragged mind-map cards, per profile, on this
/// device only. This is presentation state: links (the actual data) stay in
/// the backend, and nothing here is part of the API contract. Suggested idea
/// stars are session-only and never stored.
class MindMapLayoutStore {
  const MindMapLayoutStore._();

  static String key(String profileId) => 'mindMapLayout.$profileId';

  static Future<Map<String, Offset>> load(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key(profileId));
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, Offset>{};
      decoded.forEach((id, value) {
        if (value is List && value.length == 2 && value.every((v) => v is num)) {
          result['$id'] = Offset((value[0] as num).toDouble(), (value[1] as num).toDouble());
        }
      });
      return result;
    } catch (_) {
      return {}; // Storage unavailable or corrupt: fall back to the default layout.
    }
  }

  static Future<void> save(String profileId, Map<String, Offset> positions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key(profileId), jsonEncode({
        for (final e in positions.entries) e.key: [e.value.dx, e.value.dy],
      }));
    } catch (_) {}
  }

  static Future<void> clear(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key(profileId));
    } catch (_) {}
  }
}
