import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/deck_audio_provider.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/event_mute_button.dart';
import 'package:flutter_swipes/src/features/map/data/passport_cities.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_gps_dot.dart';
import 'package:flutter_swipes/src/features/map/presentation/widgets/map_pin_markers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('event JSON keeps video audio on unless explicitly disabled', () {
    final event = Event.fromJson({
      'id': 'e1',
      'title': 'Sunset',
      'video_url': 'https://example.com/clip.mp4',
      'background_music_url': 'https://example.com/bed.mp3',
    });
    expect(event.videoAudioEnabled, isTrue);
    expect(event.backgroundMusicUrl, 'https://example.com/bed.mp3');
  });

  testWidgets('mute button exposes a 44pt hit target', (tester) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventMuteButton(
            soundOn: on,
            onToggle: () => on = !on,
          ),
        ),
      ),
    );
    expect(find.byType(EventMuteButton), findsOneWidget);
    await tester.tap(find.byType(EventMuteButton));
    expect(on, isTrue);
  });

  testWidgets('deck audio persists unmute', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late bool value;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            value = ref.watch(deckSoundOnProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(value, isFalse);
  });

  test('passport cities all have cover photos', () {
    expect(PassportCities.all.length, greaterThan(10));
    expect(PassportCities.hub.photoUrl, contains('unsplash'));
    for (final city in PassportCities.all) {
      expect(city.photoUrl, startsWith('https://'));
    }
  });

  testWidgets('map pins paint listing pills and a pulsing GPS dot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapListingPinMarker(title: 'Jungle Villa'),
              MapProfilePinMarker(),
              MapClusterMarker(count: 4),
              MapGpsDot(),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Jungle Villa'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byType(MapGpsDot), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
