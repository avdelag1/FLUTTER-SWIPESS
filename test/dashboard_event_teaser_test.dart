import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

void main() {
  test('dashboard event teaser rows map without photo data', () {
    final event = Event.fromJson({
      'id': '00000000-0000-0000-0000-000000000001',
      'title': 'Preview Event',
      'video_url': 'https://example.com/event.mp4',
      'video_audio_enabled': true,
    });

    expect(event.title, 'Preview Event');
    expect(event.videoUrl, 'https://example.com/event.mp4');
    expect(event.imageUrl, isNull);
  });
}
