import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `useScrollDirection` shared chrome — hide header/dock while scrolling down.
class ChromeVisibilityNotifier extends Notifier<bool> {
  static const threshold = 28.0;

  double _accum = 0;

  @override
  bool build() => true;

  void show() {
    if (!state) state = true;
    _accum = 0;
  }

  void hide() {
    if (state) state = false;
    _accum = 0;
  }

  void onScroll({required double pixels, required double delta}) {
    if (pixels <= 40) {
      show();
      return;
    }

    // Ignore tiny jitter.
    if (delta.abs() < 0.5) return;

    if ((delta > 0 && _accum < 0) || (delta < 0 && _accum > 0)) {
      _accum = 0;
    }
    _accum += delta;

    if (_accum > threshold) {
      hide();
    } else if (_accum < -threshold) {
      show();
    }
  }

  void reset() {
    show();
  }
}

final chromeVisibilityProvider =
    NotifierProvider<ChromeVisibilityNotifier, bool>(ChromeVisibilityNotifier.new);
