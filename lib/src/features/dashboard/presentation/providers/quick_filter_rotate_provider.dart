import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One shared dashboard media clock.
///
/// Properties owns slot 0, then the remaining non-Events quick filters take
/// turns one-by-one. A still gets a calm 7.6 second window. A visible listing
/// video can hold its turn until playback reaches the end, so another card does
/// not change three seconds later while the movie is still running.
class QuickFilterRotateTicker extends Notifier<int> {
  static const period = Duration(milliseconds: 7600);
  Timer? _timer;
  bool _heldForVideo = false;
  int? _heldSlot;

  @override
  int build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    // Dashboard media is user-driven only. Never start an automatic timer.
    return 0;
  }

  void _armStillWindow() {
    // Intentionally no-op: photos/videos change only from explicit user input.
    _timer?.cancel();
    _timer = null;
  }

  void _advance() {
    // Intentionally no-op: keep the current quick-filter item stable.
  }

  int _normalizedSlot(int slot, int slotCount) {
    final count = slotCount.clamp(1, 64).toInt();
    final normalized = slot % count;
    return normalized < 0 ? normalized + count : normalized;
  }

  bool isTurn({required int slot, required int slotCount}) {
    final count = slotCount.clamp(1, 64).toInt();
    return state % count == _normalizedSlot(slot, count);
  }

  void holdForVideo({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    final normalized = _normalizedSlot(slot, slotCount);
    if (_heldForVideo && _heldSlot == normalized) return;
    _heldForVideo = true;
    _heldSlot = normalized;
    _timer?.cancel();
    _timer = null;
  }

  void completeVideoTurn({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    final normalized = _normalizedSlot(slot, slotCount);
    if (!_heldForVideo || _heldSlot != normalized) return;
    _heldForVideo = false;
    _heldSlot = null;
    // Do not advance automatically when a manually played video ends.
  }

  void pauseForManualVideo({required int slot, required int slotCount}) {
    final normalized = _normalizedSlot(slot, slotCount);
    _heldForVideo = true;
    _heldSlot = normalized;
    _timer?.cancel();
    _timer = null;
  }

  void resumeAfterManualVideo({required int slot, required int slotCount}) {
    final normalized = _normalizedSlot(slot, slotCount);
    if (!_heldForVideo || _heldSlot != normalized) return;
    _heldForVideo = false;
    _heldSlot = null;
    _armStillWindow();
  }

  void resumeStillWindow({required int slot, required int slotCount}) {
    if (!isTurn(slot: slot, slotCount: slotCount)) return;
    _heldForVideo = false;
    _heldSlot = null;
    _armStillWindow();
  }
}

final quickFilterRotateTickProvider =
    NotifierProvider<QuickFilterRotateTicker, int>(QuickFilterRotateTicker.new);
