import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard decks are prefetched and held briefly for instant taps', () {
    final source = File(
      'lib/src/features/swipes/presentation/providers/swipe_providers.dart',
    ).readAsStringSync();

    expect(source, contains('Duration(minutes: 2)'));
    expect(source, contains("const <String>['property', 'worker', 'yacht']"));
    expect(
      source,
      contains("const <String>['motorcycle', 'bicycle', 'services']"),
    );
  });

  test('listing photo inputs use HQ source dimensions consistently', () {
    for (final path in <String>[
      'lib/src/features/add/presentation/providers/add_listing_provider.dart',
      'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart',
      'lib/src/features/add/presentation/providers/edit_listing_provider.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('imageQuality: 93'));
      expect(source, contains('maxWidth: 2880'));
      expect(source, contains('maxHeight: 2880'));
    }
  });

  test('new listing photos are uploaded with long immutable cache headers', () {
    final source = File(
      'lib/src/features/swipes/data/repositories/listing_repository.dart',
    ).readAsStringSync();
    expect(source, contains("cacheControl: '31536000'"));
  });
}
