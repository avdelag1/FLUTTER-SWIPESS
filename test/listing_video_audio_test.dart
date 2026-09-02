import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/swipes/domain/listing_soundtrack.dart';
import 'package:flutter_swipes/src/features/swipes/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';

// Release guard for listing video mute, soundtrack persistence, and media order.
void main() {
  test('ships ten original listing soundtrack presets', () {
    expect(listingSoundtrackPresets, hasLength(10));
    expect(
      listingSoundtrackPresets.map((preset) => preset.id).toSet(),
      hasLength(10),
    );
  });

  test('procedural soundtrack is a valid non-empty WAV', () {
    final wav = buildListingSoundtrackWav('ocean');
    expect(wav.length, greaterThan(44));
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
    expect(String.fromCharCodes(wav.skip(8).take(4)), 'WAVE');
  });

  test('listing draft keeps mute and soundtrack state', () {
    final file = XFile.fromData(
      Uint8List.fromList(const [1, 2, 3]),
      name: 'my-song.mp3',
      mimeType: 'audio/mpeg',
    );
    final draft = ListingDraft(
      videoAudioEnabled: false,
      backgroundMusic: file,
      backgroundMusicName: 'my-song.mp3',
    );
    expect(draft.videoAudioEnabled, isFalse);
    expect(draft.hasBackgroundMusic, isTrue);
    final cleared = draft.copyWith(
      clearBackgroundMusic: true,
      clearBackgroundMusicName: true,
    );
    expect(cleared.backgroundMusic, isNull);
  });

  test('listing parses persisted audio choices', () {
    final listing = Listing.fromJson({
      'id': 'listing-1',
      'video_url': 'https://example.com/video.mp4',
      'video_audio_enabled': false,
      'background_music_preset': 'night_beach',
      'background_music_name': 'Night Beach',
    });
    expect(listing.videoAudioEnabled, isFalse);
    expect(listing.backgroundMusicPreset, 'night_beach');
    expect(listing.hasBackgroundMusic, isTrue);
  });

  test('manual and AI media rows put video before photos', () {
    final manual = File(
      'lib/src/features/add/presentation/screens/add_listing_screen.dart',
    ).readAsStringSync();
    final ai = File(
      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    ).readAsStringSync();

    expect(
      manual.indexOf("title: draft.video == null ? 'Video' : 'Edit video'"),
      lessThan(manual.indexOf("title: 'Photos'")),
    );
    expect(
      ai.indexOf("label: _video == null ? 'ADD VIDEO' : 'EDIT VIDEO'"),
      lessThan(
        ai.indexOf("label: _photos.isEmpty ? 'ADD PHOTOS' : 'ADD MORE'"),
      ),
    );
  });
}
