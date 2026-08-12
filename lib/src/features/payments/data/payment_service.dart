import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// IMPORTANT: Replace with actual RevenueCat API keys
const _appleApiKey = 'appl_YOUR_APPLE_KEY_HERE';
const _googleApiKey = 'goog_YOUR_GOOGLE_KEY_HERE';

class PaymentService {
  Future<void> init(String userId) async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      
      PurchasesConfiguration? configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_googleApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_appleApiKey);
      }
      
      if (configuration != null) {
        configuration.appUserID = userId;
        await Purchases.configure(configuration);
      }
    } catch (_) {
      // RevenueCat is optional until store keys are configured.
    }
  }

  Future<List<Package>> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
      return [];
    } on PlatformException {
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      // Determine if token pack was purchased and update backend accordingly
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      return false;
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});
