import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/audio_settings_provider.dart';

class AppAudio {
  static final AppAudio instance = AppAudio._();
  AppAudio._();

  // Create a few dedicated players so sounds can overlap if played quickly
  final AudioPlayer _successPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _swipePlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _aiPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Pre-load audio into memory to prevent first-play lag
    await Future.wait([
      _successPlayer.setSource(AssetSource('sounds/success.mp3')),
      _swipePlayer.setSource(AssetSource('sounds/swipe.mp3')),
      _aiPlayer.setSource(AssetSource('sounds/ai_blip.mp3')),
    ]).catchError((_) => []); // Catch errors if files don't exist yet
    _initialized = true;
  }

  Future<void> playSuccess(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.successEnabled) return;
    await _successPlayer.stop();
    await _successPlayer.play(AssetSource('sounds/success.mp3'), volume: 0.8);
  }

  Future<void> playSwipe(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.swipeEnabled) return;
    await _swipePlayer.stop();
    await _swipePlayer.play(AssetSource('sounds/swipe.mp3'), volume: 0.5);
  }

  Future<void> playAiBlip(AudioSettings settings) async {
    if (!settings.masterEnabled || !settings.aiEnabled) return;
    await _aiPlayer.stop();
    await _aiPlayer.play(AssetSource('sounds/ai_blip.mp3'), volume: 0.7);
  }
}

final appAudioProvider = Provider<AppAudio>((ref) {
  return AppAudio.instance;
});
