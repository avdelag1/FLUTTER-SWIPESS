import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Cap `src/utils/privacyScreen.ts` (`@capacitor-community/privacy-screen`).
///
/// Targeted, not global: a surface asks for protection while it is open and
/// gives it back on the way out. Android adds `FLAG_SECURE` (no screenshot, no
/// recording, blank task-switcher thumbnail); iOS covers the window while the
/// app is not frontmost, which is the only thing the platform allows.
///
/// Nested protected surfaces are reference counted, so closing the VAP ID card
/// on top of the document vault does not unprotect the vault underneath.
abstract final class PrivacyScreen {
  @visibleForTesting
  static const channel = MethodChannel('swipess/privacy_screen');

  static int _holders = 0;

  /// Number of surfaces currently asking for protection. Testing seam.
  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static void resetForTest() => _holders = 0;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> enable() async {
    if (!_supported) return;
    _holders++;
    if (_holders > 1) return;
    await _invoke('enable');
  }

  static Future<void> disable() async {
    if (!_supported) return;
    if (_holders == 0) return;
    _holders--;
    if (_holders > 0) return;
    await _invoke('disable');
  }

  static Future<void> _invoke(String method) async {
    try {
      await channel.invokeMethod<bool>(method);
    } on PlatformException catch (e) {
      debugPrint('[Privacy] $method failed: ${e.message}');
    } on MissingPluginException {
      // Host without the channel (unit tests, desktop) — nothing to protect.
    }
  }
}

/// Wraps a sensitive surface so protection follows its lifetime.
class PrivacyScreenGuard extends StatefulWidget {
  const PrivacyScreenGuard({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyScreenGuard> createState() => _PrivacyScreenGuardState();
}

class _PrivacyScreenGuardState extends State<PrivacyScreenGuard> {
  @override
  void initState() {
    super.initState();
    PrivacyScreen.enable();
  }

  @override
  void dispose() {
    PrivacyScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
