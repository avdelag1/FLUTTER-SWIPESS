import 'package:flutter/foundation.dart';

/// Cap `iapProducts.ts` + `SubscriptionPackages` + `AdvertisePage` PACKAGES.
///
/// Same App Store / Play product IDs the live Capacitor app already sells.
/// Web (and non-iOS) checkout uses the same PayPal NCP links. iOS never
/// exposes an external URL (Guideline 3.1.1).
abstract final class IapCatalog {
  static const subscriptions = <IapOffer>[
    IapOffer(
      id: 'client-unlimited-1-month',
      name: 'Here Now',
      label: 'MONTHLY',
      appleProductId: 'Swipess.plus.monthly.v3',
      googleProductId: 'swipess.plus.monthly.v2',
      priceLabel: '\$39.99',
      durationLabel: '/month',
      paypalPath: 'QSRXCJYYQ2UGY',
      benefits: [
        '6 Direct Requests included',
        'More active listings',
        'AI Concierge — 15 messages/day',
        'AI Listing Creator — 3/month',
        'Better matching & visibility',
      ],
    ),
    IapOffer(
      id: 'client-unlimited-6-months',
      name: 'Live Local',
      label: 'MOST POPULAR',
      appleProductId: 'Swipess.plus.semestral.v3',
      googleProductId: 'swipess.plus.semestral.v2',
      priceLabel: '\$119.99',
      durationLabel: '/6 months',
      paypalPath: 'HUESWJ68BRUSY',
      popular: true,
      benefits: [
        '12 Direct Requests included',
        'Higher listing limits',
        'AI Concierge — 50 messages/day',
        'AI Listing Creator — 10/month',
        'Priority matching & visibility',
        'Local Expert Knowledge',
      ],
    ),
    IapOffer(
      id: 'client-unlimited-1-year',
      name: 'Pro',
      label: 'BEST VALUE',
      appleProductId: 'Swipess.plus.annual.v3',
      googleProductId: 'swipess.plus.annual.v2',
      priceLabel: '\$299.99',
      durationLabel: '/year',
      paypalPath: '7E6R38L33LYUJ',
      benefits: [
        '30 Direct Requests included',
        'Maximum listing capacity',
        'AI Concierge — Unlimited',
        'AI Listing Creator — Unlimited',
        'Priority matching & visibility',
        'Professional growth tools',
      ],
    ),
  ];

  static const tokens = <IapOffer>[
    IapOffer(
      id: 'starter',
      name: 'Starter',
      appleProductId: 'Swipess.tokens.20.v2',
      googleProductId: 'swipess.tokens.20.v1',
      priceLabel: '\$9.99',
      tokens: 20,
      paypalPath: 'VNM2QVBFG6TA4',
      description: '20 Direct Requests',
    ),
    IapOffer(
      id: 'plus',
      name: 'Plus',
      appleProductId: 'Swipess.tokens.50.v2',
      googleProductId: 'swipess.tokens.50.v1',
      priceLabel: '\$19.99',
      tokens: 50,
      paypalPath: 'VG2C7QMAC8N6A',
      description: '50 Direct Requests',
      popular: true,
    ),
    IapOffer(
      id: 'power',
      name: 'Power',
      appleProductId: 'Swipess.tokens.100.v2',
      googleProductId: 'swipess.tokens.100.v1',
      priceLabel: '\$39.99',
      tokens: 100,
      paypalPath: '9NBGA9X3BJ5UA',
      description: '100 Direct Requests',
    ),
    IapOffer(
      id: 'mega',
      name: 'Mega',
      appleProductId: 'Swipess.tokens.150.v2',
      googleProductId: 'swipess.tokens.150.v1',
      priceLabel: '\$49.99',
      tokens: 150,
      paypalPath: 'KP9WHGEN23MYA',
      description: '150 Direct Requests',
    ),
  ];

  static const eventPromos = <IapOffer>[
    IapOffer(
      id: 'starter',
      name: 'Starter',
      appleProductId: 'Swipess.promo.event.week.v3',
      googleProductId: 'swipess.promo.event.week.v2',
      priceLabel: '\$4.99',
      durationLabel: '/ week',
      paypalPath: 'ZXQC96VYV7JLL',
      description: 'Try it for a week — no commitment',
    ),
    IapOffer(
      id: 'growth',
      name: 'Growth',
      appleProductId: 'Swipess.promo.event.month.v3',
      googleProductId: 'swipess.promo.event.month.v2',
      priceLabel: '\$49.99',
      durationLabel: '/ 3 months',
      paypalPath: 'ATKD4TR7KFTJU',
      description: 'Best value — 3 months of organic reach',
      popular: true,
    ),
    IapOffer(
      id: 'premium',
      name: 'Wave',
      appleProductId: 'Swipess.promo.event.quarter.v3',
      googleProductId: 'swipess.promo.event.quarter.v2',
      priceLabel: '\$99.99',
      durationLabel: '/ 6 months',
      paypalPath: 'LK7XWSMDHH8AW',
      description: 'Maximum reach for peak season',
    ),
  ];

  static const subscriptionIds = {
    'Swipess.plus.monthly.v3',
    'Swipess.plus.semestral.v3',
    'Swipess.plus.annual.v3',
    'swipess.plus.monthly.v2',
    'swipess.plus.semestral.v2',
    'swipess.plus.annual.v2',
  };

  static const tokenIds = {
    'Swipess.tokens.20.v2',
    'Swipess.tokens.50.v2',
    'Swipess.tokens.100.v2',
    'Swipess.tokens.150.v2',
    'swipess.tokens.20.v1',
    'swipess.tokens.50.v1',
    'swipess.tokens.100.v1',
    'swipess.tokens.150.v1',
  };

  static const promoIds = {
    'Swipess.promo.event.week.v3',
    'Swipess.promo.event.month.v3',
    'Swipess.promo.event.quarter.v3',
    'swipess.promo.event.week.v2',
    'swipess.promo.event.quarter.v2',
  };

  static bool get usesNativeStore =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Cap `getSafePaymentUrl` — never on native iOS.
  static String? paypalUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return null;
    return 'https://www.paypal.com/ncp/payment/$path';
  }

  static IapOffer? tokenById(String id) {
    for (final offer in tokens) {
      if (offer.id == id || offer.appleProductId == id || offer.googleProductId == id) return offer;
    }
    return null;
  }

  static IapOffer? promoById(String id) {
    for (final offer in eventPromos) {
      if (offer.id == id || offer.appleProductId == id || offer.googleProductId == id) return offer;
    }
    return null;
  }
}

class IapOffer {
  const IapOffer({
    required this.id,
    required this.name,
    required this.appleProductId,
    this.googleProductId,
    required this.priceLabel,
    this.label,
    this.durationLabel,
    this.description,
    this.paypalPath,
    this.tokens,
    this.benefits = const [],
    this.popular = false,
  });

  final String id;
  final String name;
  final String appleProductId;
  final String? googleProductId;
  final String priceLabel;
  final String? label;
  final String? durationLabel;
  final String? description;
  final String? paypalPath;
  final int? tokens;
  final List<String> benefits;
  final bool popular;

  String get storeProductId =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? (googleProductId ?? appleProductId)
          : appleProductId;

  bool get isSubscription =>
      IapCatalog.subscriptionIds.contains(appleProductId) ||
      (googleProductId != null && IapCatalog.subscriptionIds.contains(googleProductId));
}
