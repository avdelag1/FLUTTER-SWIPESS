enum SubscriptionTier {
  free,
  package1,
  package2,
  premium;

  static SubscriptionTier fromString(String val) {
    switch (val.toLowerCase()) {
      case 'package1':
        return SubscriptionTier.package1;
      case 'package2':
        return SubscriptionTier.package2;
      case 'premium':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  /// New free users receive the campaign welcome period through effectiveTier.
  /// Once that period ends, AI, Events and Legal are Premium benefits again.
  /// The Swipess Virtual/Local ID card remains available to every signed-in
  /// user, including the permanent free tier.
  bool get canUseAI => this != SubscriptionTier.free;
  bool get canViewEvents => this != SubscriptionTier.free;
  bool get canUseLegal => this != SubscriptionTier.free;
  bool get canUseVirtualCard => true;
  bool get canPromote => this == SubscriptionTier.premium;

  int get maxListings {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.package1:
        return 5;
      case SubscriptionTier.package2:
        return 10;
      case SubscriptionTier.premium:
        return 999999;
    }
  }

  /// Included Direct Requests for paid plans. Actual grants are authoritative
  /// on the backend; this value is presentation/domain metadata only.
  int get initialTokens {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.package1:
        return 20;
      case SubscriptionTier.package2:
        return 50;
      case SubscriptionTier.premium:
        return 150;
    }
  }
}
