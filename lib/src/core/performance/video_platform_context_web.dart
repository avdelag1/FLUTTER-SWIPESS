import 'package:web/web.dart' as web;

bool get isInstalledWebApp {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

bool get supportsNativeWebHls {
  try {
    final element = web.document.createElement('video');
    if (element is! web.HTMLVideoElement) return false;
    final apple = element.canPlayType('application/vnd.apple.mpegurl');
    final legacy = element.canPlayType('application/x-mpegURL');
    return apple.isNotEmpty || legacy.isNotEmpty;
  } catch (_) {
    return false;
  }
}
