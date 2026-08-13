import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat IAP — Cap subscription / tokens / restore.
class PaymentService {
  bool _configured = false;

  bool get isConfigured => _configured;

  String get _apiKey {
    // Avoid `dart:io` — it breaks Flutter web boot (splash hangs).
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          AppConfig.revenueCatAppleApiKey.trim().isNotEmpty) {
        return AppConfig.revenueCatAppleApiKey.trim();
      }
      if (defaultTargetPlatform == TargetPlatform.android &&
          AppConfig.revenueCatGoogleApiKey.trim().isNotEmpty) {
        return AppConfig.revenueCatGoogleApiKey.trim();
      }
    }
    return AppConfig.revenueCatApiKey.trim();
  }

  Future<void> init({String? userId}) async {
    if (_configured) {
      if (userId != null && userId.isNotEmpty) {
        try {
          await Purchases.logIn(userId);
        } catch (_) {}
      }
      return;
    }
    final key = _apiKey;
    if (key.isEmpty) return;

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.info,
      );
      final configuration = PurchasesConfiguration(key);
      if (userId != null && userId.isNotEmpty) {
        configuration.appUserID = userId;
      }
      await Purchases.configure(configuration);
      _configured = true;
    } catch (e) {
      debugPrint('RevenueCat init skipped: $e');
    }
  }

  Future<void> identify(String userId) async {
    if (!_configured || userId.isEmpty) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  Future<List<Package>> getOfferings() async {
    if (!_configured) await init();
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null && current.availablePackages.isNotEmpty) {
        return current.availablePackages;
      }
      for (final offering in offerings.all.values) {
        if (offering.availablePackages.isNotEmpty) {
          return offering.availablePackages;
        }
      }
      return [];
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    if (!_configured) await init();
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (!_configured) await init();
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cap-style RevenueCat paywall UI (requires offerings configured in RC).
  Future<PaywallResult> presentPaywall() async {
    if (!_configured) await init();
    try {
      return await RevenueCatUI.presentPaywall();
    } catch (_) {
      return PaywallResult.error;
    }
  }

  Future<CustomerInfo?> customerInfo() async {
    if (!_configured) await init();
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Keeps RevenueCat appUserID in sync with Supabase auth.
final revenueCatAuthSyncProvider = Provider<void>((ref) {
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
