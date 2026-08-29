import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/ai/domain/voice_transcript_normalize.dart';

void main() {
  test('canadian girl is a specific person search', () {
    expect(isSpecificPersonSearch('canadian girl'), isTrue);
    expect(isGeneralDiscoveryBrowse('canadian girl'), isFalse);
  });

  test('find people is general browse', () {
    expect(isSpecificPersonSearch('find people'), isFalse);
    expect(isGeneralDiscoveryBrowse('find people'), isTrue);
  });

  test('find properties is general browse', () {
    expect(isSpecificPersonSearch('find me properties'), isFalse);
    expect(isGeneralDiscoveryBrowse('find me properties'), isTrue);
  });
}
