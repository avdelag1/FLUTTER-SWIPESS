import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';

/// Web / non-IO stub — checkout goes through PayPal NCP, not StoreKit.
class NativeIap {
  NativeIap({Object? store});

  Future<void> init() async {}

  Future<CheckoutResult> purchase(String _) async => CheckoutResult.unavailable;

  Future<CheckoutResult> restore() async => CheckoutResult.unavailable;

  Future<void> dispose() async {}
}
