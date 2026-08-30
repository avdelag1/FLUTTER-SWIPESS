import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/audio_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swipess' restrained interaction sound palette.
///
/// The cues are intentionally short and quiet so they feel tactile rather than
/// game-like. Every sound respects the user's audio preferences and playback
/// failures never block the UI action that triggered them.
class AppAudio {
  static final AppAudio instance = AppAudio._();
  AppAudio._();

  static const _successAsset = 'sounds/success.mp3';
  static const _matchAsset = 'sounds/match.mp3';
  static const _aiAsset = 'sounds/ai_blip.mp3';
  static const _swipeAsset = 'sounds/swipe.mp3';
  static const _tokensAsset = 'sounds/tokens.mp3';

  final AudioPlayer _successPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _matchPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _aiPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _swipePlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _tokensPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Future.wait([
        _successPlayer.setSource(AssetSource(_successAsset)),
        _matchPlayer.setSource(AssetSource(_matchAsset)),
        _aiPlayer.setSource(AssetSource(_aiAsset)),
        _swipePlayer.setSource(AssetSource(_swipeAsset)),
        _tokensPlayer.setSource(AssetSource(_tokensAsset)),
      ]);
    } catch (_) {
      // Audio is enhancement only. Never delay or fail app startup for it.
    }
    _initialized = true;
  }

  Future<void> _play(
    AudioPlayer player,
    String asset, {
    required double volume,
  }) async {
    try {
      await init();
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // A sound cue must never interrupt the user flow.
    }
  }

  Future<AudioSettings> _settingsFromDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AudioSettings(
        masterEnabled: prefs.getBool('audio_master_enabled') ?? true,
        swipeEnabled: prefs.getBool('audio_swipe_enabled') ?? true,
        aiEnabled: prefs.getBool('audio_ai_enabled') ?? true,
        successEnabled: prefs.getBool('audio_success_enabled') ?? true,
      );
    } catch (_) {
      return const AudioSettings();
    }
  }

  Future<void> playSuccess(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.successEnabled) return;
    await _play(_successPlayer, _successAsset, volume: 0.60);
  }

  Future<void> playMatch(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.successEnabled) return;
    await _play(_matchPlayer, _matchAsset, volume: 0.64);
  }

  Future<void> playAiBlip(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.aiEnabled) return;
    await _play(_aiPlayer, _aiAsset, volume: 0.42);
  }

  Future<void> playSwipe(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.swipeEnabled) return;
    await _play(_swipePlayer, _swipeAsset, volume: 0.38);
  }

  Future<void> playTokens(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.successEnabled) return;
    await _play(_tokensPlayer, _tokensAsset, volume: 0.58);
  }

  /// Convenience methods for UI surfaces that are intentionally not tied to a
  /// Riverpod context. They still honor the same persisted Settings toggles.
  Future<void> playSuccessFromPrefs() async =>
      playSuccess(await _settingsFromDevice());

  Future<void> playMatchFromPrefs() async =>
      playMatch(await _settingsFromDevice());

  Future<void> playAiBlipFromPrefs() async =>
      playAiBlip(await _settingsFromDevice());

  Future<void> playSwipeFromPrefs() async =>
      playSwipe(await _settingsFromDevice());

  Future<void> playTokensFromPrefs() async =>
      playTokens(await _settingsFromDevice());
}

final appAudioProvider = Provider<AppAudio>((ref) => AppAudio.instance);
