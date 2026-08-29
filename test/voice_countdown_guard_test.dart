import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/domain/voice_transcript_normalize.dart';

void main() {
  group('shouldCancelVoiceCountdownForText', () {
    test('ignores empty and exact repeats', () {
      expect(
        shouldCancelVoiceCountdownForText(
          incoming: '',
          locked: 'find a plumber',
        ),
        isFalse,
      );
      expect(
        shouldCancelVoiceCountdownForText(
          incoming: 'find a plumber',
          locked: 'find a plumber',
        ),
        isFalse,
      );
    });

    test('ignores shorter restart echo', () {
      expect(
        shouldCancelVoiceCountdownForText(
          incoming: 'find a',
          locked: 'find a plumber',
        ),
        isFalse,
      );
    });

    test('cancels when user adds new words', () {
      expect(
        shouldCancelVoiceCountdownForText(
          incoming: 'find a plumber near me',
          locked: 'find a plumber',
        ),
        isTrue,
      );
    });

    test('cancels when first words arrive after empty lock', () {
      expect(
        shouldCancelVoiceCountdownForText(incoming: 'hello there', locked: ''),
        isTrue,
      );
    });
  });
}
