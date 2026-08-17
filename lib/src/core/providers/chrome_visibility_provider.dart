import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared visibility state for the persistent app chrome.
///
/// Header, dashboard AI search/filter controls and bottom dock move together:
/// scroll down to clear the content, scroll up (or return to the top) to bring
/// navigation back. Small trackpad/touch jitter is ignored so the chrome does
/// not flicker.
class ChromeVisibilityNotifier extends Notifier<bool> {
  double _downTravel = 0;
  double _upTravel = 0;

  @override
  bool build() => true;

  void show() {
    _downTravel = 0;
    if (!state) state = true;
  }

  void hide() {
    _upTravel = 0;
    if (state) state = false;
  }

  void onScroll({required double pixels, required double delta}) {
    // Always reveal navigation at the top of a page.
    if (pixels <= 8) {
      _downTravel = 0;
      _upTravel = 0;
      show();
      return;
    }

    // Ignore tiny noise from trackpads / bouncing physics.
    if (delta.abs() < 0.35) return;

    if (delta > 0) {
      _upTravel = 0;
      _downTravel += delta;
      if (pixels > 36 && _downTravel >= 14) {
        hide();
        _downTravel = 0;
      }
      return;
    }

    _downTravel = 0;
    _upTravel += -delta;
    if (_upTravel >= 10) {
      show();
      _upTravel = 0;
    }
  }

  void reset() {
    _downTravel = 0;
    _upTravel = 0;
    show();
  }
}

final chromeVisibilityProvider =
    NotifierProvider<ChromeVisibilityNotifier, bool>(
      ChromeVisibilityNotifier.new,
    );
