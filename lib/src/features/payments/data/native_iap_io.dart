import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_swipes/src/features/payments/domain/checkout_result.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// StoreKit / Play Billing using the same product IDs Capacitor already sells.
class NativeIap {
  NativeIap({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _pending = <String, Completer<CheckoutResult>>{};

  Future<void> init() async {
    if (kIsWeb || _sub != null) return;
    if (!await _store.isAvailable()) return;
    _sub = _store.purchaseStream.listen(_onPurchases);
  }

  Future<CheckoutResult> purchase(String productId) async {
    if (kIsWeb) return CheckoutResult.unavailable;
    await init();
    if (!await _store.isAvailable()) return CheckoutResult.unavailable;

    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return CheckoutResult.unavailable;

    final product = response.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    final existing = _pending[productId];
    if (existing != null) return existing.future;

    final completer = Completer<CheckoutResult>();
    _pending[productId] = completer;

    // Cap registers plus.* as PAID_SUBSCRIPTION and tokens/promo as CONSUMABLE.
    final started = IapCatalog.subscriptionIds.contains(productId)
        ? await _store.buyNonConsumable(purchaseParam: param)
        : await _store.buyConsumable(purchaseParam: param);
    if (!started) {
      _pending.remove(productId);
      return CheckoutResult.error;
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(productId);
        return CheckoutResult.cancelled;
      },
    );
  }

  Future<CheckoutResult> restore() async {
    if (kIsWeb) return CheckoutResult.unavailable;
    await init();
    try {
      await _store.restorePurchases();
      return CheckoutResult.restored;
    } catch (_) {
      return CheckoutResult.error;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      var result = CheckoutResult.error;
      if (purchase.status == PurchaseStatus.purchased) {
        final ok = await _validate(purchase);
        result = ok ? CheckoutResult.purchased : CheckoutResult.error;
      } else if (purchase.status == PurchaseStatus.restored) {
        await _validate(purchase);
        result = CheckoutResult.restored;
      } else if (purchase.status == PurchaseStatus.canceled) {
        result = CheckoutResult.cancelled;
      } else if (purchase.status == PurchaseStatus.error) {
        result = CheckoutResult.error;
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }

      final pending = _pending.remove(purchase.productID);
      if (pending != null && !pending.isCompleted) {
        pending.complete(result);
      }
    }
  }

  /// Same Cap validators: `validate-apple-receipt` / `validate-google-play-purchase`.
  Future<bool> _validate(PurchaseDetails purchase) async {
    try {
      final client = Supabase.instance.client;
      final receipt = purchase.verificationData.serverVerificationData;
      if (receipt.isEmpty) return false;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final res = await client.functions.invoke(
          'validate-apple-receipt',
          body: {
            'productId': purchase.productID,
            'transactionId': purchase.purchaseID,
            'receipt': receipt,
          },
        );
        final data = res.data;
        return data is Map && data['ok'] == true;
      }
      final res = await client.functions.invoke(
        'validate-google-play-purchase',
        body: {
          'productId': purchase.productID,
          'purchaseToken': receipt,
        },
      );
      final data = res.data;
      return data is Map && (data['ok'] == true || data['valid'] == true);
    } catch (e) {
      debugPrint('IAP validate skipped: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
