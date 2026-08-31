import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/domain/voice_transcript_normalize.dart';

void main() {
  group('voice transcript preservation', () {
    test('keeps proper names and original intent words intact', () {
      expect(
        normalizeVoiceTranscript('Find Ezriyah, the wise man in Tulum'),
        'Find Ezriyah, the wise man in Tulum',
      );
      expect(
        normalizeVoiceTranscript('Find Nena, the handmade jewelry maker'),
        'Find Nena, the handmade jewelry maker',
      );
      expect(
        normalizeVoiceTranscript('I need a shaman named Maria'),
        'I need a shaman named Maria',
      );
    });

    test('does not translate or paraphrase spoken Spanish', () {
      expect(
        normalizeVoiceTranscript('Busco a un plomero en Tulum'),
        'Busco a un plomero en Tulum',
      );
      expect(
        normalizeVoiceTranscript('Necesito un abogado y su número'),
        'Necesito un abogado y su número',
      );
      expect(
        normalizeVoiceTranscript('Quiero joyería artesanal de Nena'),
        'Quiero joyería artesanal de Nena',
      );
    });

    test('repairs only obvious recognition spelling mistakes', () {
      expect(
        normalizeVoiceTranscript('send me the whats app for someone in tuluum'),
        'send me the whatsapp for someone in tulum',
      );
      expect(normalizeVoiceTranscript('con tact info'), 'contact info');
    });

    test('specific-person routing still understands descriptive searches', () {
      expect(isSpecificPersonSearch('find me a wise man'), isTrue);
      expect(isSpecificPersonSearch('find a Canadian girl'), isTrue);
      expect(isSpecificPersonSearch('I need a shaman'), isTrue);
      expect(isSpecificPersonSearch('I need a plumber'), isFalse);
    });
  });
}
