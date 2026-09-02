import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chrome visibility with ghostly fade-out on scroll.
///
/// Instead of a hard show/hide toggle, this emits a continuous opacity value
/// (0.0–1.0) so the header and dock fade out smoothly as the user scrolls
/// down, and fade back in when scrolling up or returning to the top.
class ChromeVisibilityNotifier extends Notifier<double> {
  double _downTravel = 0;
  double _upTravel = 0;
  bool _suppressExplicitHide = false;

  /// Keep the chrome response extremely short so reels/listings feel immediate.
  /// A deliberate finger move should clear the viewport without making the
  /// user drag through a long fade first.
  static const _fadeDistance = 28.0;

  @override
  double build() => 1.0;

  /// Some immersive surfaces have their own local controls that may collapse
  /// independently. While this is enabled, their programmatic `hide()` request
  /// must not take the app's primary header/dock with it. Real user scroll still
  /// flows through [onScroll] and can fade the shared chrome normally.
  void suppressExplicitHide(bool suppress) {
    _suppressExplicitHide = suppress;
    if (suppress) show();
  }

  void show() {
    _downTravel = 0;
    _upTravel = 0;
    if (state < 1.0) state = 1.0;
  }

  void hide() {
    if (_suppressExplicitHide) {
      show();
      return;
    }
    _downTravel = 0;
    _upTravel = 0;
    if (state > 0.0) state = 0.0;
  }

  void onScroll({required double pixels, required double delta}) {
    // Always fully reveal navigation at the top of a page.
    if (pixels <= 6) {
      _downTravel = 0;
      _upTravel = 0;
      show();
      return;
    }

    // Ignore only sub-pixel jitter. Touch scrolling should react immediately.
    if (delta.abs() < 0.08) return;

    if (delta > 0) {
      // Scrolling down — clear header + dock quickly while preserving a tiny
      // progressive fade so it never flashes or visually tears.
      _upTravel = 0;
      _downTravel += delta;
      if (pixels > 12) {
        final progress = (_downTravel / _fadeDistance).clamp(0.0, 1.0);
        final target = 1.0 - progress;
        if ((state - target).abs() > 0.005) state = target;
      }
      return;
    }

    // Scrolling up — summon navigation even faster than it disappears.
    _downTravel = 0;
    _upTravel += -delta;
    final progress = (_upTravel / (_fadeDistance * 0.45)).clamp(0.0, 1.0);
    final target = progress;
    if (target > state) {
      state = target;
      if (state >= 1.0) _upTravel = 0;
    }
  }

  void reset() {
    _downTravel = 0;
    _upTravel = 0;
    _suppressExplicitHide = false;
    show();
  }
}

final chromeVisibilityProvider =
    NotifierProvider<ChromeVisibilityNotifier, double>(
      ChromeVisibilityNotifier.new,
    );
