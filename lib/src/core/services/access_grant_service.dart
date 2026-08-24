import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `isAccessGranted` — native skips the gate; web grant lasts 30 days.
class AccessGrantService {
  static const _key = 'swipess_access_grant_v1';
  static const _legacyKey = 'swipess_access_grant';
  static const _ttlMs = 30 * 24 * 60 * 60 * 1000;

  /// Capacitor native apps never show the access-code gate.
  static bool get skipOnNative => !kIsWeb;

  static Future<void> persist({String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'grantedAt': DateTime.now().millisecondsSinceEpoch,
        'v': 1,
        if (role != null) 'role': role,
      }),
    );
  }

  static Future<String?> getSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          return parsed['role'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> isGranted() async {
    if (skipOnNative) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key) ?? prefs.getString(_legacyKey);
      if (raw == null) return false;
      int? grantedAt;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          grantedAt = (parsed['grantedAt'] as num?)?.toInt();
        }
      } catch (_) {
        grantedAt = int.tryParse(raw);
      }
      if (grantedAt == null) return false;
      final elapsed = DateTime.now().millisecondsSinceEpoch - grantedAt;
      if (elapsed > _ttlMs) {
        await prefs.remove(_key);
        await prefs.remove(_legacyKey);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}
