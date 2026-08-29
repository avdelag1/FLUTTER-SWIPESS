import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desert / Burning Man visual filter — neon glyphs over a high-contrast playa.
class PlayaModeNotifier extends Notifier<bool> {
  static const _prefsKey = 'swipess_playa_mode';

  @override
  bool build() {
    Future.microtask(_hydrate);
    return false;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? false;
    if (enabled != state) state = enabled;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}

final playaModeProvider = NotifierProvider<PlayaModeNotifier, bool>(
  PlayaModeNotifier.new,
);
