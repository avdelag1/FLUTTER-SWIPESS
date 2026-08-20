import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_orchestrator.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

export 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
export 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';

/// Cap payment entry — StoreKit / Play on device, PayPal NCP on web.
class PaymentService {
  PaymentService({PaymentOrchestrator? orchestrator})
    : _orchestrator = orchestrator ?? PaymentOrchestrator();

  final PaymentOrchestrator _orchestrator;
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

  Future<CheckoutResult> buy(IapOffer offer, {String? contextId}) {
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
  return PaymentService();
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
