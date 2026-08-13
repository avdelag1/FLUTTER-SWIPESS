import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventConnect', () {
    test('builds wa.me from a promoter phone with country code', () {
      expect(
        EventConnect.whatsAppUri('+52 55 1234 5678')?.toString(),
        'https://wa.me/525512345678',
      );
      expect(
        EventConnect.whatsAppUri(
          '52 (55) 9988-7766',
          message: 'Hola, vi tu evento "Neon" en Swipess 🔥',
        )?.toString(),
        'https://wa.me/525599887766?text=${Uri.encodeComponent('Hola, vi tu evento "Neon" en Swipess 🔥')}',
      );
    });

    test('rejects short or empty WhatsApp numbers', () {
      expect(EventConnect.whatsAppUri(null), isNull);
      expect(EventConnect.whatsAppUri('1234567'), isNull);
      expect(EventConnect.hasWhatsApp('12345678'), isTrue);
    });

    test('orders social URLs from handles or full links', () {
      expect(
        EventConnect.instagramUri('@swipess')?.toString(),
        'https://www.instagram.com/swipess/',
      );
      expect(
        EventConnect.websiteUri('swipess.com')?.toString(),
        'https://swipess.com',
      );
      expect(
        EventConnect.facebookUri('swipess.club')?.toString(),
        'https://www.facebook.com/swipess.club',
      );
    });
  });

  test('Event.hasConnectLinks follows WhatsApp then other socials', () {
    const event = Event(
      id: '1',
      title: 'Neon',
      organizerWhatsapp: '+52 5512345678',
      organizerInstagram: '@host',
    );
    expect(event.hasWhatsApp, isTrue);
    expect(event.hasConnectLinks, isTrue);
    expect(
      const Event(id: '2', title: 'Quiet').hasConnectLinks,
      isFalse,
    );
  });
}
