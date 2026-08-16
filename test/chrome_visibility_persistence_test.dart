import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scrolling does not hide shared navigation chrome', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(chromeVisibilityProvider.notifier);
    expect(container.read(chromeVisibilityProvider), isTrue);

    notifier.onScroll(pixels: 240, delta: 80);
    expect(container.read(chromeVisibilityProvider), isTrue);

    notifier.hide();
    expect(container.read(chromeVisibilityProvider), isFalse);

    notifier.onScroll(pixels: 280, delta: -120);
    expect(container.read(chromeVisibilityProvider), isFalse);

    notifier.show();
    expect(container.read(chromeVisibilityProvider), isTrue);
  });
}
