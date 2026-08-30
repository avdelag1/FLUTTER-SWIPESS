import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Header/dock + card controls stay visible long enough to be useful, then the
/// deck enters an immersive state. The card itself expands after the chrome
/// leaves, matching the soft photo-first reveal used across Swipess.
class ChromeRevealState {
  const ChromeRevealState({this.chromeVisible = true, this.railVisible = true});

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

  // Three seconds felt rushed on a photo/reel surface. Keep the full HUD long
  // enough to read and interact with, then soften the side controls first and
  // let the header/dock disappear a beat later so the photo expansion reads as
  // an intentional cinematic transition instead of a sudden layout jump.
  static const railHideMs = 5600;
  static const chromeHideMs = 6200;

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
    state = const ChromeRevealState(chromeVisible: true, railVisible: true);

    _railTimer = Timer(const Duration(milliseconds: railHideMs), () {
      _railTimer = null;
      if (!state.railVisible) return;
      state = state.copyWith(railVisible: false);
    });

    _chromeTimer = Timer(const Duration(milliseconds: chromeHideMs), hide);
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
