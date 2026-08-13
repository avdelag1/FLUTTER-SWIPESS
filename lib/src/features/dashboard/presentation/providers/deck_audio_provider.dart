import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `deckAudioStore` — shared mute preference across quick-filter videos.
class DeckAudioNotifier extends Notifier<bool> {
  /// Cap `unlockMediaPlayback` — once the user unmutes, keep applying volume
  /// on newly created players (web gesture unlock persists for the session).
  bool mediaUnlocked = false;

  @override
  bool build() => false;

  void toggle() {
    state = !state;
    if (state) mediaUnlocked = true;
  }

  void setSoundOn(bool on) {
    state = on;
    if (on) mediaUnlocked = true;
  }
}

final deckSoundOnProvider =
    NotifierProvider<DeckAudioNotifier, bool>(DeckAudioNotifier.new);
