class OAuthPopupHandle {
  const OAuthPopupHandle();
}

OAuthPopupHandle? openOAuthPopupPlaceholder() => null;

bool navigateOAuthPopup(OAuthPopupHandle? handle, String url) => false;

bool isOAuthPopupClosed(OAuthPopupHandle? handle) => true;

void closeOAuthPopup(OAuthPopupHandle? handle) {}
