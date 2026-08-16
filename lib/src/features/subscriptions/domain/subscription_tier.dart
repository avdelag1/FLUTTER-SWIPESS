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

  bool get canUseAI => this == SubscriptionTier.package2 || this == SubscriptionTier.premium;
  bool get canViewEvents => this != SubscriptionTier.free;
  bool get canUseVirtualCard => this != SubscriptionTier.free;
  bool get canPromote => this == SubscriptionTier.premium; // Not explicitly defined, assuming premium

  int get maxListings {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.package1:
        return 5;
      case SubscriptionTier.package2:
        return 10;
      case SubscriptionTier.premium:
        return 999999; // unlimited
    }
  }

  int get initialTokens {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.package1:
        return 15;
      case SubscriptionTier.package2:
        return 25;
      case SubscriptionTier.premium:
        return 999999;
    }
  }
}
