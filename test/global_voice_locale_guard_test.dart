import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('native speech resolves the exact locale advertised by the device', () {
    final service = _source(
      'lib/src/features/ai/presentation/services/live_voice_input.dart',
    );

    expect(service, contains("replaceAll('_', '-')"));
    expect(service, contains('return exact.first.localeId;'));
  });

  test('AI listing and chat share the global explicit voice language', () {
    final builder = _source(
      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
    );
    final chat = _source(
      'lib/src/features/messages/presentation/screens/chat_screen.dart',
    );

    expect(builder, contains('ref.read(voiceLanguageProvider).localeCode'));
    expect(chat, contains('ref.read(voiceLanguageProvider).localeCode'));
  });
}
