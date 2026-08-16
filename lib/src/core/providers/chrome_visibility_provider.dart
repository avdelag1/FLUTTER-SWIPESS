import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared visibility state for the persistent app chrome.
///
/// Header and dock must not disappear just because a user scrolls. That
/// behavior made controls feel unreliable and could leave users on a page with
/// no obvious navigation. Explicit immersive surfaces (for example the AI
/// overlay) may still call [hide] and [show] deliberately.
class ChromeVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() {
    if (!state) state = true;
  }

  void hide() {
    if (state) state = false;
  }

  /// Retained for callers that report scroll position, but scrolling no longer
  /// changes navigation visibility. Persistent navigation is intentional.
  void onScroll({required double pixels, required double delta}) {}

  void reset() => show();
}

final chromeVisibilityProvider =
    NotifierProvider<ChromeVisibilityNotifier, bool>(
      ChromeVisibilityNotifier.new,
    );
