import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `src/utils/appReview.ts` (`@capacitor-community/in-app-review`).
///
/// Ask at a genuinely happy moment — a mutual match — but only once the user
/// has felt the value (their second match) and at most once every 90 days on
/// our side. The OS throttles much harder on top of that, so a wasted ask is
/// expensive: iOS may simply ignore prompts for the rest of the year.
class AppReview {
  AppReview({InAppReview? review}) : _review = review ?? InAppReview.instance;

  static const _matchesKey = 'swipess_review_matches';
  static const _lastAskedKey = 'swipess_review_last_asked';
  static const _minMatches = 2;
  static const _cooldown = Duration(days: 90);

  final InAppReview _review;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Counts the match and returns whether the prompt was requested.
  Future<bool> maybeRequestAfterMatch() async {
    if (!_supported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final matches = (prefs.getInt(_matchesKey) ?? 0) + 1;
      await prefs.setInt(_matchesKey, matches);

      final lastAsked = prefs.getInt(_lastAskedKey) ?? 0;
      final since = DateTime.now().millisecondsSinceEpoch - lastAsked;
      if (matches < _minMatches || since <= _cooldown.inMilliseconds) {
        return false;
      }
      if (!await _review.isAvailable()) return false;

      await prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);
      await _review.requestReview();
      return true;
    } catch (e) {
      debugPrint('[AppReview] gate error: $e');
      return false;
    }
  }
}
