import 'package:shared_preferences/shared_preferences.dart';

/// Device-local reusable signature for Swipess Sign.
///
/// The reusable signature is intentionally kept on the user's device rather
/// than in a public profile. Contract signatures themselves are still written
/// to the secured contract signature records when a document is signed.
abstract final class SavedSignatureStore {
  static const _key = 'swipess_saved_signature_v1';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> save(String dataUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dataUrl);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
