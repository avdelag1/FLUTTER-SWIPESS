// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

/// Browser/PWA notification support that requires no native plugin.
///
/// These reminders work while the installed PWA/browser session is still
/// alive. Fully terminated web push still needs a Push API subscription and a
/// server-side VAPID sender, so this bridge never pretends a timer is push.
class WebNotificationsBridge {
  const WebNotificationsBridge._();

  static final List<Timer> _timers = <Timer>[];

  static bool get isSupported {
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }

  static bool get permissionGranted {
    if (!isSupported) return false;
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    if (permissionGranted) return true;
    try {
      final result = await html.Notification.requestPermission();
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void scheduleReengagement() {
    if (!permissionGranted) return;
    cancelReengagement();

    _schedule(
      const Duration(minutes: 45),
      'Consistency Challenge ⚡',
      'Your challenge is waiting. Come back and keep building toward your free token.',
    );
    _schedule(
      const Duration(days: 3),
      'Your matches miss you 👀',
      'New listings and people are waiting for you on Swipess.',
    );
    _schedule(
      const Duration(days: 7),
      "Don't miss out 🔥",
      'Fresh matches near you — come take a look.',
    );
  }

  static void cancelReengagement() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  static void _schedule(Duration after, String title, String body) {
    _timers.add(
      Timer(after, () {
        if (!permissionGranted) return;
        try {
          html.Notification(title, body: body, icon: 'icons/Icon-192.png');
        } catch (_) {
          // Browser notification support is best-effort and must never affect
          // the Flutter session if the browser changes its permission state.
        }
      }),
    );
  }
}
