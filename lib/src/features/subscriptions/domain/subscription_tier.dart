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

  // Existing non-marketplace membership areas remain untouched by the Direct
  // Request redesign. Events and Legal keep their current entitlement rules.
  bool get canUseAI => this != SubscriptionTier.free;
  bool get canViewEvents => this != SubscriptionTier.free;
  bool get canUseLegal => this != SubscriptionTier.free;
  bool get canUseVirtualCard => this != SubscriptionTier.free;
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

  /// Included Direct Request allowance granted by the membership layer.
  ///
  /// Never use an unlimited sentinel here: Direct Requests are intentionally
  /// finite so priority cannot become spam. Purchased token packs remain a
  /// separate pay-as-you-go balance and follow the same accepted-only rule.
  int get initialTokens {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.package1:
        return 15;
      case SubscriptionTier.package2:
        return 25;
      case SubscriptionTier.premium:
        return 50;
    }
  }
}
