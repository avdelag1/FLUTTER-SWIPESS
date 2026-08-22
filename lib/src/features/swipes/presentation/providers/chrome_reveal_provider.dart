import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap `useChromeReveal` — header/dock + rail fade after idle on the swipe deck.
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

  static const chromeHideMs = 7000;
  static const railHideMs = 7000;

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
