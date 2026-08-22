class OAuthPopupHandle {
  const OAuthPopupHandle();
}

OAuthPopupHandle? openOAuthPopupPlaceholder() => null;

bool navigateOAuthPopup(OAuthPopupHandle? handle, String url) => false;

void closeOAuthPopup(OAuthPopupHandle? handle) {}
