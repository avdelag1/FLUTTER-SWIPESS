import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edit listing mirrors the full listing video editor controls', () {
    final screen = File(
      'lib/src/features/add/presentation/screens/edit_listing_screen.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/src/features/add/presentation/providers/edit_listing_provider.dart',
    ).readAsStringSync();
    final cropper = File(
      'lib/src/features/camera/presentation/screens/video_cropper_screen_v2.dart',
    ).readAsStringSync();

    expect(screen, contains('materializeRemoteMedia'));
    expect(screen, contains('VideoCropperScreen'));
    expect(screen, contains('ListingVideoSoundtrackPicker'));
    expect(screen, contains("label: Text('Edit video')"));
    expect(screen, contains("'Original video sound'"));
    expect(provider, contains("payload['video_audio_enabled']"));
    expect(provider, contains("payload['background_music_url']"));
    expect(provider, contains("payload['background_music_preset']"));
    expect(provider, contains("payload['background_music_name']"));
    expect(cropper, contains('SWIPESS AUDIO · 10 BUILT-IN SOUNDS'));
  });

  test('AI listing microphone has a real listening health watchdog', () {
    final ai = File(
      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    ).readAsStringSync();

    expect(ai, contains('Timer? _micHealthTimer;'));
    expect(ai, contains('int _micRecoveryAttempt = 0;'));
    expect(ai, contains('onListeningChanged: (listening)'));
    expect(ai, contains('_voice.listeningNotifier.value'));
    expect(ai, contains("languageCode: 'en-US'"));
    expect(ai, contains("? 'MIC LIVE'"));
    expect(ai, contains("'RECOVERING'"));
    expect(ai, contains('_scheduleMicRestart();'));
  });
}
