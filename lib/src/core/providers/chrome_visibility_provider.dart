import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chrome visibility with ghostly fade-out on scroll.
///
/// Instead of a hard show/hide toggle, this emits a continuous opacity value
/// (0.0–1.0) so the header and dock fade out smoothly as the user scrolls
/// down, and fade back in when scrolling up or returning to the top.
class ChromeVisibilityNotifier extends Notifier<double> {
  double _downTravel = 0;
  double _upTravel = 0;

  /// How many px of downward scroll fully fades the chrome.
  static const _fadeDistance = 60.0;

  @override
  double build() => 1.0;

  void show() {
    _downTravel = 0;
    if (state < 1.0) state = 1.0;
  }

  void hide() {
    _upTravel = 0;
    if (state > 0.0) state = 0.0;
  }

  void onScroll({required double pixels, required double delta}) {
    // Always fully reveal navigation at the top of a page.
    if (pixels <= 8) {
      _downTravel = 0;
      _upTravel = 0;
      show();
      return;
    }

    // Ignore tiny noise from trackpads / bouncing physics.
    if (delta.abs() < 0.35) return;

    if (delta > 0) {
      // Scrolling down — fade out progressively.
      _upTravel = 0;
      _downTravel += delta;
      if (pixels > 36) {
        final progress = (_downTravel / _fadeDistance).clamp(0.0, 1.0);
        final target = 1.0 - progress;
        if ((state - target).abs() > 0.01) {
          state = target;
        }
      }
      return;
    }

    // Scrolling up — fade back in progressively.
    _downTravel = 0;
    _upTravel += -delta;
    final progress = (_upTravel / (_fadeDistance * 0.6)).clamp(0.0, 1.0);
    final target = progress;
    if (target > state) {
      state = target;
      if (state >= 1.0) _upTravel = 0;
    }
  }

  void reset() {
    _downTravel = 0;
    _upTravel = 0;
    show();
  }
}

final chromeVisibilityProvider =
    NotifierProvider<ChromeVisibilityNotifier, double>(
      ChromeVisibilityNotifier.new,
    );
