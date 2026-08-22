// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

class OAuthPopupHandle {
  OAuthPopupHandle(this.window);

  final html.WindowBase window;
}

OAuthPopupHandle? openOAuthPopupPlaceholder() {
  try {
    final popup = html.window.open(
      'about:blank',
      'swipess_oauth',
      'popup=yes,width=520,height=720,resizable=yes,scrollbars=yes',
    );
    popup.focus();
    return OAuthPopupHandle(popup);
  } catch (_) {
    return null;
  }
}

bool navigateOAuthPopup(OAuthPopupHandle? handle, String url) {
  if (handle == null) return false;
  try {
    if (handle.window.closed == true) return false;
    handle.window.location.href = url;
    handle.window.focus();
    return true;
  } catch (_) {
    return false;
  }
}

void closeOAuthPopup(OAuthPopupHandle? handle) {
  if (handle == null) return;
  try {
    handle.window.close();
  } catch (_) {}
}
