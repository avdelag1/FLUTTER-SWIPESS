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
  final _pendingContext = <String, String>{};

  Future<void> init() async {
    if (kIsWeb || _sub != null) return;
    if (!await _store.isAvailable()) return;
    _sub = _store.purchaseStream.listen(_onPurchases);
  }

  Future<CheckoutResult> purchase(String productId, {String? contextId}) async {
    if (kIsWeb) return CheckoutResult.unavailable;
    await init();
    if (!await _store.isAvailable()) return CheckoutResult.unavailable;

    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return CheckoutResult.unavailable;

    final product = response.productDetails.first;
    final appUserId = Supabase.instance.client.auth.currentUser?.id;
    final param = PurchaseParam(
      productDetails: product,
      // Supabase user IDs are UUIDs. On StoreKit 2 this is carried as the app
      // account token, giving server notifications a stable account identity;
      // on Google Play it becomes the obfuscated account identifier.
      applicationUserName: appUserId,
    );
    final existing = _pending[productId];
    if (existing != null) return existing.future;

    final completer = Completer<CheckoutResult>();
    _pending[productId] = completer;
    if (contextId != null && contextId.trim().isNotEmpty) {
      _pendingContext[productId] = contextId.trim();
    }

    // Cap registers plus.* as PAID_SUBSCRIPTION and tokens/promo as CONSUMABLE.
    final started = IapCatalog.subscriptionIds.contains(productId)
        ? await _store.buyNonConsumable(purchaseParam: param)
        : await _store.buyConsumable(purchaseParam: param);
    if (!started) {
      _pending.remove(productId);
      _pendingContext.remove(productId);
      return CheckoutResult.error;
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(productId);
        _pendingContext.remove(productId);
        return CheckoutResult.cancelled;
      },
    );
  }

  Future<CheckoutResult> restore() async {
    if (kIsWeb) return CheckoutResult.unavailable;
    await init();
    try {
      await _store.restorePurchases(
        applicationUserName: Supabase.instance.client.auth.currentUser?.id,
      );
      return CheckoutResult.restored;
    } catch (_) {
      return CheckoutResult.error;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      var result = CheckoutResult.error;
      var validationPassed = false;

      if (purchase.status == PurchaseStatus.purchased) {
        validationPassed = await _validate(purchase);
        result = validationPassed
            ? CheckoutResult.purchased
            : CheckoutResult.error;
      } else if (purchase.status == PurchaseStatus.restored) {
        validationPassed = await _validate(purchase);
        result = validationPassed
            ? CheckoutResult.restored
            : CheckoutResult.error;
      } else if (purchase.status == PurchaseStatus.canceled) {
        result = CheckoutResult.cancelled;
        validationPassed = true;
      } else if (purchase.status == PurchaseStatus.error) {
        result = CheckoutResult.error;
        validationPassed = true;
      }

      if (purchase.pendingCompletePurchase && validationPassed) {
        await _store.completePurchase(purchase);
      }

      _pendingContext.remove(purchase.productID);
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
      final submissionId = _pendingContext[purchase.productID];
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final res = await client.functions.invoke(
          'validate-apple-receipt',
          body: {
            'productId': purchase.productID,
            'transactionId': purchase.purchaseID,
            'receipt': receipt,
            if (submissionId != null) 'submissionId': submissionId,
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
          if (submissionId != null) 'submissionId': submissionId,
        },
      );
      final data = res.data;
      return data is Map && (data['ok'] == true || data['valid'] == true);
    } catch (e) {
      debugPrint('IAP validation failed: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _pendingContext.clear();
  }
}
