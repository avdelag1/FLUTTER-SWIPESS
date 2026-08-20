import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/payments/data/native_iap.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cap `PaymentOrchestrator` — native IAP on iOS/Android, PayPal NCP on web.
class PaymentOrchestrator {
  PaymentOrchestrator({NativeIap? native}) : _native = native ?? NativeIap();

  final NativeIap _native;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    if (IapCatalog.usesNativeStore) {
      await _native.init();
    }
    _ready = true;
  }

  Future<CheckoutResult> purchase({
    required String storeProductId,
    String? paypalPath,
    String? contextId,
  }) async {
    await init();
    if (IapCatalog.usesNativeStore) {
      return _native.purchase(storeProductId, contextId: contextId);
    }

    final url = IapCatalog.paypalUrl(paypalPath);
    if (url == null) return CheckoutResult.unavailable;

    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok ? CheckoutResult.openedWebCheckout : CheckoutResult.error;
    } catch (e) {
      debugPrint('PayPal checkout failed: $e');
      return CheckoutResult.error;
    }
  }

  Future<CheckoutResult> restore() async {
    await init();
    if (!IapCatalog.usesNativeStore) {
      return CheckoutResult.unavailable;
    }
    return _native.restore();
  }
}
