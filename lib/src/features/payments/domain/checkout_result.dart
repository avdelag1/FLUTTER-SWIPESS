/// Outcome of Cap `PaymentOrchestrator.purchase` / `restore`.
enum CheckoutResult {
  purchased,
  restored,
  cancelled,
  openedWebCheckout,
  complimentaryAccessActive,
  unavailable,
  error,
}

extension CheckoutResultX on CheckoutResult {
  bool get isSuccess =>
      this == CheckoutResult.purchased || this == CheckoutResult.restored;

  String get userMessage => switch (this) {
    CheckoutResult.purchased => 'Purchase complete.',
    CheckoutResult.restored => 'Purchases restored.',
    CheckoutResult.cancelled => 'Checkout cancelled.',
    CheckoutResult.openedWebCheckout =>
      'PayPal opened — finish checkout there. Tokens refresh after the webhook.',
    CheckoutResult.complimentaryAccessActive =>
      'Your complimentary Premium access is still active. We won’t charge you for overlapping membership access.',
    CheckoutResult.unavailable =>
      'This plan is only available through the App Store on iOS.',
    CheckoutResult.error => 'Checkout failed. Try again in a moment.',
  };
}
