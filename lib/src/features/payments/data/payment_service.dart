import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_orchestrator.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';

export 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
export 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

/// Cap payment entry — StoreKit / Play on device, PayPal NCP on web.
class PaymentService {
  PaymentService({
    PaymentOrchestrator? orchestrator,
    Future<bool> Function()? complimentaryAccessActive,
  })  : _orchestrator = orchestrator ?? PaymentOrchestrator(),
        _complimentaryAccessActive = complimentaryAccessActive;

  final PaymentOrchestrator _orchestrator;
  final Future<bool> Function()? _complimentaryAccessActive;
  bool _configured = false;

  bool get isConfigured => _configured;

  Future<void> init({String? userId}) async {
    await _orchestrator.init();
    _configured = true;
  }

  Future<void> identify(String userId) async {
    if (userId.isEmpty) return;
  }

  Future<void> logOut() async {}

  bool _isSubscription(IapOffer offer) => IapCatalog.subscriptions.any(
        (candidate) =>
            candidate.id == offer.id ||
            candidate.storeProductId == offer.storeProductId,
      );

  Future<CheckoutResult> buy(IapOffer offer, {String? contextId}) async {
    // The three-month welcome campaign is app-managed complimentary access,
    // not an App Store introductory subscription. Do not start a paid
    // membership while that access is still active; token packs remain
    // purchasable because they are separate pay-as-you-go priority products.
    if (_isSubscription(offer) &&
        await (_complimentaryAccessActive?.call() ?? Future.value(false))) {
      return CheckoutResult.complimentaryAccessActive;
    }

    return _orchestrator.purchase(
      storeProductId: offer.storeProductId,
      paypalPath: offer.paypalPath,
      contextId: contextId,
    );
  }

  Future<CheckoutResult> buyProduct({
    required String storeProductId,
    String? paypalPath,
    String? contextId,
  }) {
    return _orchestrator.purchase(
      storeProductId: storeProductId,
      paypalPath: paypalPath,
      contextId: contextId,
    );
  }

  Future<CheckoutResult> restorePurchases() => _orchestrator.restore();

  /// Opens the first subscription offer (Cap paywall equivalent).
  Future<CheckoutResult> presentPaywall() {
    final offer = IapCatalog.subscriptions.first;
    return buy(offer);
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(
    complimentaryAccessActive: () async {
      final subscription = await ref.read(subscriptionProvider.future);
      return subscription.isTrialActive;
    },
  );
});

final paymentAuthSyncProvider = Provider<void>((ref) {
  ref.listen(currentUserProvider, (previous, next) {
    final payments = ref.read(paymentServiceProvider);
    final user = next;
    if (user != null) {
      payments.identify(user.id);
    } else {
      payments.logOut();
    }
  });
});
