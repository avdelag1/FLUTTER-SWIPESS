import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared deck/media sound preference.
///
/// `state` is the effective sound state currently exposed to players.
/// `_userPreference` is the user's persisted choice. Temporary route-level
/// suppression (for example while Map is open) never overwrites that choice,
/// so returning from Map restores sound exactly as it was before.
class DeckAudioNotifier extends Notifier<bool> {
  static const prefsKey = 'swipess-deck-audio-v1';

  bool _userPreference = false;
  int _temporaryMuteDepth = 0;

  /// Once the user unmutes, keep applying volume on newly created players
  /// (web gesture unlock persists for the session).
  bool mediaUnlocked = false;

  bool get userPreference => _userPreference;
  bool get temporarilySuppressed => _temporaryMuteDepth > 0;

  @override
  bool build() {
    Future.microtask(_hydrate);
    return false;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    _userPreference = prefs.getBool(prefsKey) ?? false;
    if (_userPreference) mediaUnlocked = true;
    _publishEffectiveState();
  }

  Future<void> _persistPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, _userPreference);
  }

  void _publishEffectiveState() {
    final effective = _userPreference && _temporaryMuteDepth == 0;
    if (state != effective) state = effective;
  }

  void toggle() {
    _userPreference = !_userPreference;
    if (_userPreference) mediaUnlocked = true;
    _publishEffectiveState();
    _persistPreference();
  }

  void setSoundOn(bool on) {
    _userPreference = on;
    if (on) mediaUnlocked = true;
    _publishEffectiveState();
    _persistPreference();
  }

  /// Temporarily mute every consumer of [deckSoundOnProvider] without changing
  /// the user's saved sound preference. Calls are reference-counted so nested
  /// map/globe layers cannot accidentally restore sound too early.
  void suspendTemporarily() {
    _temporaryMuteDepth++;
    _publishEffectiveState();
  }

  /// Release one temporary mute request. When the last request is released,
  /// sound returns only if the user had sound enabled before the suppression.
  void resumeTemporarySound() {
    if (_temporaryMuteDepth > 0) _temporaryMuteDepth--;
    _publishEffectiveState();
  }
}

final deckSoundOnProvider = NotifierProvider<DeckAudioNotifier, bool>(
  DeckAudioNotifier.new,
);
