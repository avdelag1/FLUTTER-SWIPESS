import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Header/dock + card controls stay visible long enough to be useful, then the
/// deck enters an immersive state in three deliberate stages:
/// controls soften, chrome leaves, then the photo expands.
class ChromeRevealState {
  const ChromeRevealState({
    this.chromeVisible = true,
    this.railVisible = true,
    this.photoExpanded = false,
  });

  final bool chromeVisible;
  final bool railVisible;
  final bool photoExpanded;

  ChromeRevealState copyWith({
    bool? chromeVisible,
    bool? railVisible,
    bool? photoExpanded,
  }) {
    return ChromeRevealState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      railVisible: railVisible ?? this.railVisible,
      photoExpanded: photoExpanded ?? this.photoExpanded,
    );
  }
}

class ChromeRevealNotifier extends Notifier<ChromeRevealState> {
  Timer? _chromeTimer;
  Timer? _railTimer;
  Timer? _expandTimer;

  // Give people time to actually use the HUD. The stagger prevents the photo
  // from growing underneath controls that are still visually leaving.
  static const railHideMs = 6800;
  static const chromeHideMs = 7600;
  static const photoExpandDelayMs = 340;

  @override
  ChromeRevealState build() {
    ref.onDispose(_clear);
    return const ChromeRevealState();
  }

  void _clear() {
    _chromeTimer?.cancel();
    _railTimer?.cancel();
    _expandTimer?.cancel();
    _chromeTimer = null;
    _railTimer = null;
    _expandTimer = null;
  }

  void reveal() {
    // Riverpod does not allow provider state changes while Flutter is building
    // the widget tree. Swipe screens may request a reveal from initState or
    // didUpdateWidget, so defer only that lifecycle-time mutation to the end
    // of the current frame. User-triggered reveals still happen immediately.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => reveal());
      return;
    }

    _clear();
    state = const ChromeRevealState(
      chromeVisible: true,
      railVisible: true,
      photoExpanded: false,
    );

    _railTimer = Timer(const Duration(milliseconds: railHideMs), () {
      _railTimer = null;
      if (!state.railVisible) return;
      state = state.copyWith(railVisible: false);
    });

    _chromeTimer = Timer(const Duration(milliseconds: chromeHideMs), () {
      _chromeTimer = null;
      _beginImmersiveExit();
    });
  }

  /// Resets the idle countdown only while the HUD is already on-screen.
  /// Browsing while fully immersive stays immersive instead of flashing chrome
  /// back into view on every vertical page.
  void keepAlive() {
    if (!state.chromeVisible && !state.railVisible) return;
    reveal();
  }

  void _beginImmersiveExit() {
    _railTimer?.cancel();
    _railTimer = null;
    _expandTimer?.cancel();
    state = state.copyWith(
      chromeVisible: false,
      railVisible: false,
      photoExpanded: false,
    );
    _expandTimer = Timer(
      const Duration(milliseconds: photoExpandDelayMs),
      () {
        _expandTimer = null;
        if (state.chromeVisible || state.railVisible) return;
        state = state.copyWith(photoExpanded: true);
      },
    );
  }

  void hide() {
    _clear();
    _beginImmersiveExit();
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
