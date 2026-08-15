import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `deckAudioStore` — shared mute, persisted so unmute survives restarts.
class DeckAudioNotifier extends Notifier<bool> {
  static const prefsKey = 'swipess-deck-audio-v1';

  /// Cap `unlockMediaPlayback` — once the user unmutes, keep applying volume
  /// on newly created players (web gesture unlock persists for the session).
  bool mediaUnlocked = false;

  @override
  bool build() {
    Future.microtask(_hydrate);
    return false;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool(prefsKey) ?? false;
    if (!on || state) return;
    state = true;
    mediaUnlocked = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, state);
  }

  void toggle() {
    state = !state;
    if (state) mediaUnlocked = true;
    _persist();
  }

  void setSoundOn(bool on) {
    state = on;
    if (on) mediaUnlocked = true;
    _persist();
  }
}

final deckSoundOnProvider = NotifierProvider<DeckAudioNotifier, bool>(
  DeckAudioNotifier.new,
);
