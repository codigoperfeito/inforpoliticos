import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheStore {
  const CacheStore({
    this.ttl = const Duration(hours: 6),
  });

  final Duration ttl;

  Future<Map<String, dynamic>?> readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final timestamp = DateTime.tryParse(data['timestamp'] as String? ?? '');
    if (timestamp == null) {
      return null;
    }
    if (DateTime.now().difference(timestamp) > ttl) {
      return null;
    }
    final payload = data['payload'] as Map<String, dynamic>?;
    return payload;
  }

  Future<void> writeJson(String key, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'payload': payload,
    };
    await prefs.setString(key, jsonEncode(data));
  }

  Future<DateTime?> lastUpdated(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final timestamp = DateTime.tryParse(data['timestamp'] as String? ?? '');
    return timestamp;
  }
}
