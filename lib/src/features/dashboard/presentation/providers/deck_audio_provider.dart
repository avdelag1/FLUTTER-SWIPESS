import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `deckAudioStore` — shared mute preference across quick-filter videos.
class DeckAudioNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setSoundOn(bool on) => state = on;
}

final deckSoundOnProvider =
    NotifierProvider<DeckAudioNotifier, bool>(DeckAudioNotifier.new);
