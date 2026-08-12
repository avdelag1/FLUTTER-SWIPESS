import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the web app's access grant logic exactly.
/// Grant is stored locally and valid for 30 days.
class AccessGrantService {
  static const _key = 'swipess_access_grant';
  static const _ttlMs = 30 * 24 * 60 * 60 * 1000; // 30 days

  /// Persist a successful access grant to local storage.
  static Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, '${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Returns true if the user has previously entered a valid code within 30 days.
  static Future<bool> isGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return false;
      final grantedAt = int.tryParse(raw);
      if (grantedAt == null) return false;
      final elapsed = DateTime.now().millisecondsSinceEpoch - grantedAt;
      if (elapsed > _ttlMs) {
        await prefs.remove(_key);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clear the access grant (e.g. on logout or expiry).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
