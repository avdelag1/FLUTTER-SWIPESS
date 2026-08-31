enum SubscriptionTier {
  free,
  package1,
  package2,
  premium;

  /// Launch mode: every signed-in user gets full product access without a
  /// paywall. Flip to false when monetization is turned back on.
  static const unlockAllFeatures = true;

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

  /// Once [unlockAllFeatures] is false, AI, Events and Legal are Premium again.
  /// The Swipess Virtual/Local ID card remains available to every signed-in
  /// user, including the permanent free tier.
  bool get canUseAI => unlockAllFeatures || this != SubscriptionTier.free;
  bool get canViewEvents => unlockAllFeatures || this != SubscriptionTier.free;
  bool get canUseLegal => unlockAllFeatures || this != SubscriptionTier.free;
  bool get canUseVirtualCard => true;
  bool get canPromote => unlockAllFeatures || this == SubscriptionTier.premium;
  bool get canAccessProfileInsights =>
      unlockAllFeatures || this != SubscriptionTier.free;

  /// Higher weight = more likely to appear first in AI, map and feed discovery.
  int get discoveryBoostWeight {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.package1:
        return 1;
      case SubscriptionTier.package2:
        return 2;
      case SubscriptionTier.premium:
        return 3;
    }
  }

  String get discoveryBenefitLabel {
    switch (this) {
      case SubscriptionTier.free:
        return 'Standard discovery';
      case SubscriptionTier.package1:
        return 'AI discoverability — found by service, price & reputation';
      case SubscriptionTier.package2:
        return '2× profile views in feeds, map & search';
      case SubscriptionTier.premium:
        return 'First in AI & local results + maximum visibility';
    }
  }

  int get insightsRetentionDays {
    if (unlockAllFeatures) return 365;
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.package1:
        return 30;
      case SubscriptionTier.package2:
        return 90;
      case SubscriptionTier.premium:
        return 365;
    }
  }

  int get maxListings {
    if (unlockAllFeatures) return 999999;
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
    if (unlockAllFeatures) return 150;
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
