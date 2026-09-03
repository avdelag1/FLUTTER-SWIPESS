// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class OAuthPopupHandle {
  OAuthPopupHandle(this.window);

  final html.WindowBase window;
}

StreamSubscription<html.MessageEvent>? _oauthCompletionSub;

void _installOAuthCompletionRedirect() {
  _oauthCompletionSub?.cancel();
  _oauthCompletionSub = html.window.onMessage.listen((event) {
    if (event.origin != html.window.location.origin) return;
    final data = event.data;
    if (data is! Map || data['type'] != 'swipess-oauth-complete') return;

    // The OAuth popup and the opener share the same localStorage on web/PWA.
    // Once the popup confirms Supabase persisted the session, reload the opener
    // at the app root so bootstrap restores that session before GoRouter can
    // render Welcome/Auth again. This also makes browser/PWA back navigation
    // land in the signed-in app instead of the old login page.
    _oauthCompletionSub?.cancel();
    _oauthCompletionSub = null;
    html.window.location.replace('/');
  });
}

OAuthPopupHandle? openOAuthPopupPlaceholder() {
  try {
    _installOAuthCompletionRedirect();
    final popup = html.window.open(
      'about:blank',
      'swipess_oauth',
      'popup=yes,width=520,height=720,resizable=yes,scrollbars=yes',
    );
    return OAuthPopupHandle(popup);
  } catch (_) {
    _oauthCompletionSub?.cancel();
    _oauthCompletionSub = null;
    return null;
  }
}

bool navigateOAuthPopup(OAuthPopupHandle? handle, String url) {
  if (handle == null) return false;
  try {
    if (handle.window.closed == true) return false;
    handle.window.location.href = url;
    return true;
  } catch (_) {
    return false;
  }
}

bool isOAuthPopupClosed(OAuthPopupHandle? handle) {
  if (handle == null) return true;
  try {
    return handle.window.closed == true;
  } catch (_) {
    return true;
  }
}

void closeOAuthPopup(OAuthPopupHandle? handle) {
  if (handle == null) return;
  try {
    handle.window.close();
  } catch (_) {}
}
