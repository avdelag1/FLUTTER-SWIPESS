import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `useChromeReveal` — header/dock + rail fade after idle on the swipe deck.
class ChromeRevealState {
  const ChromeRevealState({
    this.chromeVisible = true,
    this.railVisible = true,
  });

  final bool chromeVisible;
  final bool railVisible;

  ChromeRevealState copyWith({bool? chromeVisible, bool? railVisible}) {
    return ChromeRevealState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      railVisible: railVisible ?? this.railVisible,
    );
  }
}

class ChromeRevealNotifier extends Notifier<ChromeRevealState> {
  Timer? _chromeTimer;
  Timer? _railTimer;

  /// User asked ~5s; Cap uses 4s / 4.5s — use 5s / 5.5s for chrome / rail.
  static const chromeHideMs = 5000;
  static const railHideMs = 5500;

  @override
  ChromeRevealState build() {
    ref.onDispose(_clear);
    return const ChromeRevealState();
  }

  void _clear() {
    _chromeTimer?.cancel();
    _railTimer?.cancel();
    _chromeTimer = null;
    _railTimer = null;
  }

  void reveal() {
    _clear();
    state = const ChromeRevealState(chromeVisible: true, railVisible: true);
    _chromeTimer = Timer(const Duration(milliseconds: chromeHideMs), () {
      state = state.copyWith(chromeVisible: false);
    });
    _railTimer = Timer(const Duration(milliseconds: railHideMs), () {
      state = state.copyWith(railVisible: false);
    });
  }

  void hide() {
    _clear();
    state = const ChromeRevealState(chromeVisible: false, railVisible: false);
  }

  void toggle() {
    if (state.chromeVisible || state.railVisible) {
      hide();
    } else {
      reveal();
    }
  }
}

final chromeRevealProvider =
    NotifierProvider<ChromeRevealNotifier, ChromeRevealState>(
  ChromeRevealNotifier.new,
);
