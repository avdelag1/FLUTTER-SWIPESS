import 'package:web/web.dart' as web;

bool get isInstalledWebApp {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}
