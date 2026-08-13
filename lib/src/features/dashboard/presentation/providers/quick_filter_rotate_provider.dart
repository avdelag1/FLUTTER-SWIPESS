import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Round-robin ticker so only **one** quick-filter card advances every ~6.8s
/// (instead of every card flipping at once).
class QuickFilterRotateTicker extends Notifier<int> {
  static const period = Duration(milliseconds: 6800);
  Timer? _timer;

  @override
  int build() {
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) {
      state = state + 1;
    });
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return 0;
  }
}

final quickFilterRotateTickProvider =
    NotifierProvider<QuickFilterRotateTicker, int>(QuickFilterRotateTicker.new);
